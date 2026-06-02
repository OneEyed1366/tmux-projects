-- Mirror of share/SPEC.md path_to_session_name contract.
-- Both bash and lua implementations must produce identical results for
-- the same input. This is the lua side of the symmetry contract.

local this_file = debug.getinfo(1, "S").source:sub(2)
local helpers = dofile(vim.fn.fnamemodify(this_file, ":h") .. "/_helpers.lua")
local new_set, eq = MiniTest.new_set, MiniTest.expect.equality

local tmux = require("tmux-projects.tmux")

local T = new_set({
    hooks = { pre_case = helpers.reset_module },
})

local cases = {
    -- почему: SYMMETRY with bash. Both impls must drop the leading
    -- dot in the basename. bash uses `base="${base#.}"`; lua uses
    -- `base:gsub("^%.", "")`. If they diverge, the same project
    -- gets two different session names depending on which UI
    -- created it.
    { "leading dot in basename is dropped",     "/Users/x/.config",  "config" },
    { "leading dot, second case",               "/Users/x/.ssh",     "ssh" },
    -- почему: tmux target syntax separator → safe transliteration.
    { "spaces in basename → underscores",       "/Users/x/my project", "my_project" },
    { "dots in basename → underscores",         "/Users/x/a.b/c.d",  "c_d" },
    { "colons in basename → underscores",       "/var/log:weird",    "log_weird" },
    { "slashes in basename → underscores",      "/x/foo/bar",        "bar" },
    { "simple basename unchanged",              "/var/log",          "log" },
    { "nested path uses basename only",         "/very/deep/foo",    "foo" },
    -- почему: SYMMETRY with bash. The lua impl must strip
    -- trailing slashes BEFORE `vim.fn.fnamemodify(p, ":t")` or
    -- the result is "". This was the real bug caught on
    -- 2026-06-02: the first test run failed exactly here.
    { "trailing slash is irrelevant",           "/Users/x/projects/", "projects" },
    { "empty input → empty",                    "",                  "" },
}

for _, c in ipairs(cases) do
    T[c[1]] = function()
        eq(c[3], tmux.path_to_session_name(c[2]))
    end
end

return T
