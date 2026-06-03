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

-- Domain API. Pickers call these — they never assemble tmux command
-- arg vectors themselves. The shapes (signature, return tuple, error
-- signaling) are part of the picker/tmux.lua contract, not part of
-- the tmux(1) CLI.

function M.has_session(name)
    local r = vim.system(M.cmd("has-session", "-t=" .. name), { text = true }):wait()
    return r.code == 0
end

function M.kill_session(name)
    local r = vim.system(M.cmd("kill-session", "-t", name), { text = true }):wait()
    if r.code ~= 0 then
        return false, r.stderr or ""
    end
    return true
end

function M.rename_session(old_name, new_name)
    local r = vim.system(M.cmd("rename-session", "-t", old_name, new_name), { text = true }):wait()
    if r.code ~= 0 then
        return false, r.stderr or ""
    end
    return true
end

-- Spawn the session pane via an INTERACTIVE login shell (-i -l) so
-- ~/.zshrc runs and nvm/node/mason all land in PATH. Without -i, zsh
-- only sources zshenv+zprofile and nvm is missing. Then exec nvim;
-- on nvim exit, drop back into a shell so the pane stays.
--
-- This string is duplicated in bin/tmux-sessionizer (bash side);
-- the contract lives in share/SPEC.md. Update both sides together.
--
-- SHELL fallback: bash uses `${SHELL:-/bin/zsh}` which falls back on
-- nil AND empty. Lua's `or` only falls back on nil — a literal
-- `""` is truthy. So at SHELL="" the lua side would build
-- `" -ilc 'nvim; exec  -il'"` (broken). Explicit check matches
-- bash semantics; SYMMETRY with the contract.
local function shell_launch_inner_cmd()
    local shell = vim.env.SHELL
    if not shell or shell == "" then
        shell = "/bin/zsh"
    end
    return shell .. " -ilc 'nvim; exec " .. shell .. " -il'"
end

function M.open_or_attach(name, path)
    if not M.has_session(name) then
        local r = vim.system(M.cmd("new-session", "-ds", name, "-c", path, shell_launch_inner_cmd()), { text = true })
            :wait()
        if r.code ~= 0 then
            return false, r.stderr or ""
        end
    end
    M.attach(name)
    return true
end

function M.attach(name)
    local cmd = (vim.env.TMUX and vim.env.TMUX ~= "") and "switch-client" or "attach"
    vim.system(M.cmd(cmd, "-t", name)):wait()
end

function M.path_to_session_name(p)
    -- vim.fn.fnamemodify(p, ":t") returns "" when p ends in "/",
    -- unlike coreutils `basename` which strips it. Match bash behavior.
    p = (p:gsub("/+$", ""))
    local base = vim.fn.fnamemodify(p, ":t")
    base = base:gsub("^%.", "")
    base = base:gsub("[ %.:/]", "_")
    return base
end

-- Canonical form for a path passed into a tmux.* API: absolute
-- (resolves `~`, `./`, `../`, relative-to-cwd), trailing-slash
-- stripped. Centralizing this means callers (actions/open, etc.)
-- don't each repeat the same one-liner, and the contract
-- "tmux.* functions take canonical paths" is enforced in one
-- place. SYMMETRY with bash: `bin/tmux-sessionizer:318,338,341`
-- does the equivalent normalization (`cd && pwd`, `${var%/}`).
function M.normalize_path(p)
    p = vim.fn.fnamemodify(p, ":p")
    p = p:gsub("/+$", "")
    return p
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
