local M = {}

local function tmux_bin()
    if vim.fn.executable("tmux") == 1 then
        return "tmux"
    end
    for _, p in ipairs({
        "/opt/homebrew/bin/tmux",
        "/usr/local/bin/tmux",
        "/usr/bin/tmux",
    }) do
        if vim.uv.fs_stat(p) then
            return p
        end
    end
    return "tmux"
end

local function socket_name()
    local s = vim.env.TMUX_SOCKET
    if s and s ~= "" then
        return s
    end
    local tmux_env = vim.env.TMUX
    if tmux_env and tmux_env ~= "" then
        local sock_path = tmux_env:match("^([^,]+)")
        if sock_path then
            return vim.fn.fnamemodify(sock_path, ":t")
        end
    end
    return nil
end

function M.cmd(...)
    local args = { tmux_bin() }
    local sock = socket_name()
    if sock and sock ~= "" then
        table.insert(args, "-L")
        table.insert(args, sock)
    end
    for _, a in ipairs({ ... }) do
        table.insert(args, a)
    end
    return args
end

function M.path_to_session_name(p)
    local base = vim.fn.fnamemodify(p, ":t")
    base = base:gsub("^%.", "")
    base = base:gsub("[ %.:/]", "_")
    return base
end

function M.live_sessions()
    local result = vim.system(M.cmd("list-sessions", "-F", "#{session_name}"), { text = true }):wait()
    if result.code ~= 0 then
        return {}
    end
    local out = {}
    for line in (result.stdout or ""):gmatch("[^\r\n]+") do
        if line ~= "" then
            table.insert(out, line)
        end
    end
    return out
end

return M
