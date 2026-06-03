local M = {}

local config = require("tmux-projects.config")
local pins = require("tmux-projects.pins")
local native = require("tmux-projects.pickers.native")
local keys = require("tmux-projects.pickers.keys")
local list = require("tmux-projects.pickers.actions.list")
local open_action = require("tmux-projects.pickers.actions.open")
local delete_action = require("tmux-projects.pickers.actions.delete")
local rename_action = require("tmux-projects.pickers.actions.rename")

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

-- Rebuild the picker's entry list in place. Called after a delete
-- or rename action so the user sees the updated picker (the changed
-- row reflects the action, the list is re-sorted, the filter is
-- preserved). Keeping the user in the same picker avoids the
-- close-and-reopen dance that would lose the filter text and the
-- row position.
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
            results = list.build(),
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
    local entries = list.build()

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
                        open_action.attach(e.name)
                    elseif e.kind == "browse" then
                        vim.schedule(function()
                            local chosen = native.pick_folder()
                            if not chosen or chosen == "" then
                                return
                            end
                            chosen = chosen:gsub("/$", "")
                            pins.add(cfg.extra_file, chosen)
                            open_action.open(chosen)
                        end)
                    elseif e.kind == "pinned" or e.kind == "scanned" then
                        open_action.open(e.path)
                    end
                end)

                -- Declarative keymap wiring. The wrapper closures
                -- (delete_current, rename_current) and the dual-
                -- buffer binding logic used to live here, ~30 lines
                -- of boilerplate. Now in `pickers/keys.lua`; this
                -- file is just the picker construction + open-path
                -- delegation. Caveats about <C-d> / <C-r> footguns
                -- and focus drift now live with the wiring they
                -- describe.
                keys.bind(prompt_bufnr, map, {
                    {
                        "d",
                        "<C-d>",
                        "delete",
                        function(e)
                            delete_action.delete(prompt_bufnr, e, refresh_picker)
                        end,
                    },
                    {
                        "r",
                        "<C-r>",
                        "rename",
                        function(e)
                            rename_action.rename(prompt_bufnr, e, refresh_picker)
                        end,
                    },
                })

                return true
            end,
        })
        :find()
end

return M
