local M = {}

local function default_config()
    return {
        roots = { vim.env.HOME .. "/projects", vim.env.HOME .. "/personal" },
        extra_file = vim.env.HOME .. "/.config/tmux-projects.txt",
        browse_label = "+ Browse for folder…",
        max_depth = 5,
    }
end

function M.get()
    local user = M._user or {}
    local defaults = default_config()
    return vim.tbl_deep_extend("force", defaults, user)
end

function M.setup(user_config)
    M._user = user_config or {}
end

return M
