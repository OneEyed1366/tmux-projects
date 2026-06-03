-- Open (or attach to) a project. Strips trailing slashes and
-- normalizes to an absolute path so the path matches what scan.lua
-- and pins.lua write.

local M = {}

local tmux = require("tmux-projects.tmux")

function M.open(path)
    path = tmux.normalize_path(path)
    local name = tmux.path_to_session_name(path)
    local ok, err = tmux.open_or_attach(name, path)
    if not ok then
        vim.notify("tmux open failed: " .. tostring(err or ""), vim.log.levels.ERROR)
    end
end

function M.attach(name)
    tmux.attach(name)
end

return M
