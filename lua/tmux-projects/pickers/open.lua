local M = {}

local config = require("tmux-projects.config")
local tmux = require("tmux-projects.tmux")
local scan = require("tmux-projects.scan")
local pins = require("tmux-projects.pins")
local native = require("tmux-projects.pickers.native")

-- Hoisted to module level (NOT inside M.open) because module-level
-- functions like `refresh_picker` need them as upvalues, and they
-- must resolve regardless of the call-site. If they were local to
-- M.open, a `refresh_picker` invocation from a deferred callback
-- (e.g. dressing.nvim's wrapped `vim.ui.input` callback that fires
-- via `vim.schedule`) would see them as nil globals and crash with
-- `attempt to index global 'action_state' (a nil value)`.
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local function build_entries()
    local cfg = config.get()
    local entries = { { kind = "browse", label = cfg.browse_label } }

    local live = tmux.live_sessions()
    local live_set = {}
    for _, s in ipairs(live) do
        live_set[s] = true
        table.insert(entries, { kind = "live", label = "● " .. s, name = s })
    end

    for _, p in ipairs(pins.read(cfg.extra_file)) do
        local sess = tmux.path_to_session_name(p)
        if not live_set[sess] then
            table.insert(entries, { kind = "pinned", label = "★ " .. p, path = p })
        end
    end

    for _, p in ipairs(scan.scanned_dirs(cfg.roots, cfg.max_depth)) do
        local sess = tmux.path_to_session_name(p)
        if not live_set[sess] then
            table.insert(entries, { kind = "scanned", label = "  " .. p, path = p })
        end
    end

    return entries
end

local function open_project(path)
    path = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
    local name = tmux.path_to_session_name(path)

    local r = vim.system(tmux.cmd("has-session", "-t=" .. name), { text = true }):wait()
    if r.code ~= 0 then
        local shell = vim.env.SHELL or "/bin/zsh"
        local inner = shell .. " -ilc 'nvim; exec " .. shell .. " -il'"
        local create = vim.system(tmux.cmd("new-session", "-ds", name, "-c", path, inner), { text = true }):wait()
        if create.code ~= 0 then
            vim.notify("tmux new-session failed: " .. (create.stderr or ""), vim.log.levels.ERROR)
            return
        end
    end

    local cmd = (vim.env.TMUX and vim.env.TMUX ~= "") and "switch-client" or "attach"
    vim.system(tmux.cmd(cmd, "-t", name)):wait()
end

local function attach_to_existing_session(name)
    local cmd = (vim.env.TMUX and vim.env.TMUX ~= "") and "switch-client" or "attach"
    vim.system(tmux.cmd(cmd, "-t", name)):wait()
end

-- Confirm-then-act helper. Returns true if the user accepted.
-- Uses vim.ui.select with native Neovim UI; no extra deps.
local function confirm(prompt, on_yes)
    vim.ui.select({ "Yes", "No" }, {
        prompt = prompt,
    }, function(choice)
        if choice == "Yes" then
            on_yes()
        end
    end)
end

-- Rebuild the picker's entry list in place. Called after a delete
-- action so the user sees the updated picker (the deleted row is
-- gone, the list is re-sorted, the filter is preserved). Keeping the
-- user in the same picker avoids the close-and-reopen dance that
-- would lose the filter text and the row position.
--
-- `reset_prompt = false` keeps the current filter text so the user
-- can keep iterating through a filtered set. We re-fetch the picker
-- via `action_state.get_current_picker` rather than capturing a
-- closure upvalue: closures over `local picker_instance` were
-- unreliable in this code path (see the prior
-- `attempt-to-index-global-picker_instance` debugging).
local function refresh_picker(prompt_bufnr)
    local picker = action_state.get_current_picker(prompt_bufnr)
    if not picker then
        return
    end
    picker:refresh(
        finders.new_table({
            results = build_entries(),
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.label,
                    ordinal = entry.label,
                }
            end,
        }),
        {
            reset_prompt = false,
        }
    )

    -- Restore focus to the prompt buffer. After a deferred
    -- callback (e.g. dressing.nvim's `vim.ui.input` wrapper firing
    -- via `vim.schedule`), focus may have drifted to the results
    -- buffer, which is nomodifiable. Pressing `i` there yields
    -- E21: "Cannot make changes, 'modifiable' is off", and the
    -- user is stuck looking at a frozen picker. The schedule
    -- defers the focus restore so it runs after the refresh's
    -- internal redraw is settled.
    if vim.api.nvim_buf_is_valid(prompt_bufnr) then
        vim.schedule(function()
            if vim.api.nvim_buf_is_valid(prompt_bufnr) then
                vim.api.nvim_set_current_buf(prompt_bufnr)
            end
        end)
    end
end

-- Delete the current picker entry. Three cases by row kind:
--   * `browse` — UI affordance, no project. Refuse.
--   * `live` — orphan session (not pinned, not scanned). Confirm +
--     kill the session. (No unpin: there's no pin entry.)
--   * `scanned` — auto-discovered, not in pin file. Refuse: there is
--     no pin to remove, and the path will regenerate on the next
--     picker open from the scan. To hide, add a hidden-projects
--     mechanism (not yet implemented).
--   * `pinned` — in the pin file. If a live session exists for it,
--     confirm to kill+unpin; else confirm to unpin only.
--
-- After every successful action, `refresh_picker` is called so the
-- user stays in the updated picker (deleted row gone, list re-sorted).
local function delete_entry(prompt_bufnr, e)
    local cfg = config.get()

    if e.kind == "browse" then
        vim.notify("Cannot delete the browse entry", vim.log.levels.WARN)
        return
    end

    if e.kind == "live" then
        confirm(string.format("Kill tmux session '%s'?", e.name), function()
            local killed = vim.system(tmux.cmd("kill-session", "-t", e.name)):wait()
            if killed.code ~= 0 then
                vim.notify("kill-session failed: " .. (killed.stderr or ""), vim.log.levels.ERROR)
                return
            end
            vim.notify("Killed session: " .. e.name, vim.log.levels.INFO)
            refresh_picker(prompt_bufnr)
        end)
        return
    end

    if e.kind == "scanned" then
        vim.notify("Cannot hide auto-discovered projects", vim.log.levels.INFO)
        return
    end

    local path = e.path
    local name = tmux.path_to_session_name(path)

    local has_session = vim.system(tmux.cmd("has-session", "-t=" .. name), { text = true }):wait().code == 0

    local function do_unpin()
        local ok, removed = pcall(pins.remove, cfg.extra_file, path)
        if not ok then
            vim.notify("unpin failed: " .. tostring(removed), vim.log.levels.ERROR)
            return
        end
        if removed then
            vim.notify("Unpinned: " .. path, vim.log.levels.INFO)
        else
            -- Defensive: kind is "pinned" (we rejected "scanned" above)
            -- but the file changed under us between picker open and key
            -- press. Tell the truth rather than claim a success.
            vim.notify("Not in pin file: " .. path, vim.log.levels.INFO)
        end
    end

    if has_session then
        confirm(string.format("Project '%s' has a live tmux session. Kill it AND unpin?", name), function()
            local killed = vim.system(tmux.cmd("kill-session", "-t", name)):wait()
            if killed.code ~= 0 then
                vim.notify("kill-session failed: " .. (killed.stderr or ""), vim.log.levels.ERROR)
                return
            end
            do_unpin()
            refresh_picker(prompt_bufnr)
        end)
    else
        confirm(string.format("Remove '%s' from the picker?", path), function()
            do_unpin()
            refresh_picker(prompt_bufnr)
        end)
    end
end

-- Rename the tmux session of the current picker entry. Cases:
--   * `browse` / `scanned` — no session to rename. Refuse.
--   * `pinned` (no live session) — the path has no live session
--     yet, so there's nothing to rename. The user would normally
--     open the project first (Enter) to create the session, then
--     come back to rename. Refuse with a hint.
--   * `live` or `pinned` (with live session) — prompt for a new
--     name and run `tmux rename-session -t <old> <new>`. The pin
--     file is NOT updated (it's a list of paths, not session
--     names), so after a rename the picker will show both `● <new>`
--     and `★ /path` for the same project. The user can clean up
--     by unpinning and re-browsing if they care.
local function rename_entry(prompt_bufnr, e)
    if e.kind == "browse" then
        vim.notify("Cannot rename the browse entry", vim.log.levels.WARN)
        return
    end

    if e.kind == "scanned" then
        vim.notify("Cannot rename auto-discovered projects", vim.log.levels.INFO)
        return
    end

    local old_name
    if e.kind == "live" then
        old_name = e.name
    elseif e.kind == "pinned" then
        local derived = tmux.path_to_session_name(e.path)
        local has = vim.system(tmux.cmd("has-session", "-t=" .. derived), { text = true }):wait().code == 0
        if not has then
            vim.notify("No live session for " .. e.path .. " (open it first)", vim.log.levels.INFO)
            return
        end
        old_name = derived
    end

    vim.ui.input({
        prompt = "Rename '" .. old_name .. "' to: ",
        default = old_name,
    }, function(new_name)
        if not new_name or new_name == "" or new_name == old_name then
            return
        end
        local renamed = vim.system(tmux.cmd("rename-session", "-t", old_name, new_name), { text = true }):wait()
        if renamed.code ~= 0 then
            vim.notify("rename-session failed: " .. (renamed.stderr or ""), vim.log.levels.ERROR)
            return
        end
        vim.notify("Renamed: " .. old_name .. " → " .. new_name, vim.log.levels.INFO)
        refresh_picker(prompt_bufnr)
    end)
end

function M.open()
    if not (vim.env.TMUX and vim.env.TMUX ~= "") then
        vim.notify("Not running inside tmux", vim.log.levels.WARN)
        return
    end
    local ok = pcall(require, "telescope")
    if not ok then
        vim.notify("telescope.nvim not loaded", vim.log.levels.ERROR)
        return
    end

    local cfg = config.get()
    local entries = build_entries()

    -- Telescope's Picker has no public `change_title` (verified
    -- empirically: the only `change_title` in telescope is on
    -- `preview.border`, not on the picker). So `prompt_title` is
    -- set once at picker creation and stays. We list BOTH
    -- bindings (normal-mode `d` AND insert-mode `<C-d>`) in the
    -- static title so the user can see what's available, the way
    -- a help footer would.
    pickers
        .new({}, {
            prompt_title = "tmux projects  (Enter=open  d=delete  r=rename)",
            finder = finders.new_table({
                results = entries,
                entry_maker = function(e)
                    return {
                        value = e,
                        display = e.label,
                        ordinal = e.label,
                    }
                end,
            }),
            sorter = conf.generic_sorter({}),
            layout_strategy = "vertical",
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    local picked = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if not picked then
                        return
                    end
                    local e = picked.value

                    if e.kind == "live" then
                        attach_to_existing_session(e.name)
                    elseif e.kind == "browse" then
                        vim.schedule(function()
                            local chosen = native.pick_folder()
                            if not chosen or chosen == "" then
                                return
                            end
                            chosen = chosen:gsub("/$", "")
                            pins.add(cfg.extra_file, chosen)
                            open_project(chosen)
                        end)
                    elseif e.kind == "pinned" or e.kind == "scanned" then
                        open_project(e.path)
                    end
                end)

                -- `d` (normal) / `<C-d>` (insert) → delete the current
                -- entry. In normal mode we use bare `d` (vim muscle
                -- memory for the `dd` line-delete command). In insert
                -- mode we use `<C-d>` instead because bare letters
                -- would just type into the filter prompt.
                --
                -- Buffer-local keymap fires before operator-pending
                -- mode, so `d` does not get re-interpreted as the
                -- start of a `d{motion}` sequence.
                --
                -- Caveat: telescope's default `<C-d>` is
                -- `preview_scrolling_down`, but our picker has no
                -- preview pane, so the default is a no-op. We still
                -- override it because it's the most discoverable
                -- single binding for insert-mode users.
                local function delete_current()
                    local picked = action_state.get_selected_entry()
                    if not picked then
                        vim.notify("Nothing selected to delete", vim.log.levels.WARN)
                        return
                    end
                    delete_entry(prompt_bufnr, picked.value)
                end
                map("n", "d", delete_current)
                map("i", "<C-d>", delete_current)

                -- `r` (normal) / `<C-r>` (insert) → rename the current
                -- entry's tmux session. In normal mode we use bare
                -- `r` (vim muscle memory for the rename operator in
                -- ex/`:r` and for `R` replace-mode entry). In insert
                -- mode we use `<C-r>` because bare letters would
                -- just type into the filter prompt.
                --
                -- Bound in BOTH modes and on BOTH the prompt and
                -- results buffers: the action should work regardless
                -- of focus drift and regardless of which mode the
                -- user is in.
                --
                -- Caveat: `<C-r>` in insert mode is normally vim's
                -- "paste from register" (e.g. `<C-r>0` to paste from
                -- the unnamed register). In a regular text buffer
                -- that default is sacred. In the picker prompt buffer
                -- it's a footgun: the user typing a filter never wants
                -- to paste a register into the filter, and an
                -- accidental `<C-r>` without a register name drops
                -- the picker into a "waiting for register" state
                -- (and the next keystrokes get captured into a
                -- register as a side effect). Overriding here is
                -- safe and expected.
                local function rename_current()
                    local picked = action_state.get_selected_entry()
                    if not picked then
                        vim.notify("Nothing selected to rename", vim.log.levels.WARN)
                        return
                    end
                    rename_entry(prompt_bufnr, picked.value)
                end
                map("n", "r", rename_current)
                map("i", "<C-r>", rename_current)

                -- Also bind on the results buffer so focus drift
                -- doesn't break the action. The results_bufnr is
                -- set by telescope when it creates the picker.
                local picker = action_state.get_current_picker(prompt_bufnr)
                if picker and picker.results_bufnr and vim.api.nvim_buf_is_valid(picker.results_bufnr) then
                    local results_bufnr = picker.results_bufnr
                    vim.keymap.set("n", "d", delete_current, { buffer = results_bufnr, silent = true })
                    vim.keymap.set("i", "<C-d>", delete_current, { buffer = results_bufnr, silent = true })

                    vim.keymap.set("n", "r", rename_current, { buffer = results_bufnr, silent = true })
                    vim.keymap.set("i", "<C-r>", rename_current, { buffer = results_bufnr, silent = true })
                end

                return true
            end,
        })
        :find()
end

return M
