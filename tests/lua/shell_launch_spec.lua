-- Contract: bin/tmux-sessionizer (bash) and lua/tmux-projects/tmux.lua
-- must spawn the session pane with the structural form
-- `-ilc 'nvim; exec <shell> -il'`. Drift breaks the symmetry
-- contract in share/SPEC.md (Session pane shell). Without this
-- test, the contract relied on code review and a comment in
-- tmux.lua — drift would be caught by humans, not CI.
--
-- Scope of this test: catches *removal* or *structural breakage*
-- of the shell-launch form on either side. Does NOT compare
-- the two forms byte-for-byte (the middle `<shell>` differs
-- syntactically — bash `${SHELL:-/bin/zsh}` vs lua
-- `shell .. " -ilc 'nvim; exec " .. shell .. " -il"` — even
-- though both evaluate to the same runtime string). Finer
-- SHELL-handling drift (e.g. the SHELL="" asymmetry between
-- `${VAR:-default}` and `or`) is covered by manual review.

local this_file = debug.getinfo(1).source:sub(2)
local new_set = MiniTest.new_set

local T = new_set()

local function read_file(path)
    local f = assert(io.open(path, "r"))
    local c = f:read("*a")
    f:close()
    return c
end

-- The structural form must appear somewhere in each file. The
-- regex uses Lua's non-greedy `.-` to span whatever the language
-- uses for SHELL substitution.
local function has_shell_launch_form(content)
    return content:find("%-ilc 'nvim; exec.-%-il'", 1) ~= nil
end

T["session pane shell: bash side uses the structural form"] = function()
    local spec_dir = vim.fn.fnamemodify(this_file, ":h")
    local project_root = vim.fn.fnamemodify(spec_dir, ":h:h")
    local bash = read_file(project_root .. "/bin/tmux-sessionizer")
    assert(
        has_shell_launch_form(bash),
        "bash side missing shell-launch form (searched bin/tmux-sessionizer)"
    )
end

T["session pane shell: lua side uses the structural form"] = function()
    local spec_dir = vim.fn.fnamemodify(this_file, ":h")
    local project_root = vim.fn.fnamemodify(spec_dir, ":h:h")
    local lua_ = read_file(project_root .. "/lua/tmux-projects/tmux.lua")
    assert(
        has_shell_launch_form(lua_),
        "lua side missing shell-launch form (searched lua/tmux-projects/tmux.lua)"
    )
end

return T
