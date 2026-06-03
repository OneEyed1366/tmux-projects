-- Rename the tmux session of the current picker entry. Cases:
--   * `browse` / `scanned` — no session to rename. Refuse.
--   * `pinned` (no live session) — the path has no live session
--     yet, so there's nothing to rename. The user would normally
--     open the project first (Enter) to create the session, then
--     come back to rename. Refuse with a hint.
--   * `live` or `pinned` (with live session) — prompt for a new
--     name and rename the session. The pin file is NOT updated
--     (it's a list of paths, not session names), so after a rename
--     the picker will show both `● <new>` and `★ /path` for the
--     same project. The user can clean up by unpinning and
--     re-browsing if they care.

local M = {}

local tmux = require("tmux-projects.tmux")

function M.rename(prompt_bufnr, e, refresh_picker)
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
        if not tmux.has_session(derived) then
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
        local ok, err = tmux.rename_session(old_name, new_name)
        if not ok then
            vim.notify("rename-session failed: " .. tostring(err or ""), vim.log.levels.ERROR)
            return
        end
        vim.notify("Renamed: " .. old_name .. " → " .. new_name, vim.log.levels.INFO)
        refresh_picker(prompt_bufnr)
    end)
end

return M
