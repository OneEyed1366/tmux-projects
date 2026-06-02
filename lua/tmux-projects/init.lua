local M = {}

local config = require("tmux-projects.config")
local pickers_open = require("tmux-projects.pickers.open")
local pickers_kill = require("tmux-projects.pickers.kill")

function M.setup(user_config)
    config.setup(user_config)
end

function M.open()
    pickers_open.open()
end

function M.kill()
    pickers_kill.kill()
end

return M
