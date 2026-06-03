-- Delete the current picker entry. Kind-dispatch is centralized
-- here (the picker itself only forwards the action) so that adding
-- a new kind or a new action touches exactly one place.
--
-- Cases by row kind:
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

local M = {}

local config = require("tmux-projects.config")
local tmux = require("tmux-projects.tmux")
local pins = require("tmux-projects.pins")
local ui = require("tmux-projects.pickers.actions.ui")

function M.delete(prompt_bufnr, e, refresh_picker)
    local cfg = config.get()

    if e.kind == "browse" then
        vim.notify("Cannot delete the browse entry", vim.log.levels.WARN)
        return
    end

    if e.kind == "live" then
        ui.confirm(string.format("Kill tmux session '%s'?", e.name), function()
            local ok, err = tmux.kill_session(e.name)
            if not ok then
                vim.notify("kill-session failed: " .. tostring(err or ""), vim.log.levels.ERROR)
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

    if tmux.has_session(name) then
        ui.confirm(string.format("Project '%s' has a live tmux session. Kill it AND unpin?", name), function()
            local ok, err = tmux.kill_session(name)
            if not ok then
                vim.notify("kill-session failed: " .. tostring(err or ""), vim.log.levels.ERROR)
                return
            end
            do_unpin()
            refresh_picker(prompt_bufnr)
        end)
    else
        ui.confirm(string.format("Remove '%s' from the picker?", path), function()
            do_unpin()
            refresh_picker(prompt_bufnr)
        end)
    end
end

return M
