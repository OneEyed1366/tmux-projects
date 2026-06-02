-- Tests for tmux-projects.config — defaults, user override, deep merge.

local this_file = debug.getinfo(1, "S").source:sub(2)
local helpers = dofile(vim.fn.fnamemodify(this_file, ":h") .. "/_helpers.lua")
local new_set, eq = MiniTest.new_set, MiniTest.expect.equality

local T = new_set({ hooks = { pre_case = helpers.reset_module } })

T["default_config: provides roots list with HOME prefix"] = function()
    local cfg = require("tmux-projects.config")
    cfg.setup({})
    local g = cfg.get()
    eq(2, #g.roots)
    eq(vim.env.HOME .. "/projects", g.roots[1])
    eq(vim.env.HOME .. "/personal", g.roots[2])
end

T["default_config: extra_file under HOME/.config"] = function()
    local cfg = require("tmux-projects.config")
    cfg.setup({})
    local g = cfg.get()
    eq(vim.env.HOME .. "/.config/tmux-projects.txt", g.extra_file)
end

T["default_config: browse_label is non-empty"] = function()
    local cfg = require("tmux-projects.config")
    cfg.setup({})
    local g = cfg.get()
    assert(g.browse_label and g.browse_label ~= "", "browse_label should be set")
end

T["default_config: max_depth is positive integer"] = function()
    local cfg = require("tmux-projects.config")
    cfg.setup({})
    local g = cfg.get()
    eq("number", type(g.max_depth))
    assert(g.max_depth > 0, "max_depth should be positive")
end

-- почему: `roots` is a sequence (table), so deep-merge would
-- concatenate `default + user` which is surprising. The
-- implementation uses `vim.tbl_deep_extend("force", ...)` which
-- replaces. Documented behavior = REPLACE for tables, FALLBACK
-- for scalars.
T["user roots REPLACES default (table override)"] = function()
    local cfg = require("tmux-projects.config")
    cfg.setup({ roots = { "/custom/a", "/custom/b" } })
    local g = cfg.get()
    eq({ "/custom/a", "/custom/b" }, g.roots)
end

T["user max_depth overrides default"] = function()
    local cfg = require("tmux-projects.config")
    cfg.setup({ max_depth = 10 })
    local g = cfg.get()
    eq(10, g.max_depth)
end

T["unset keys fall back to default"] = function()
    local cfg = require("tmux-projects.config")
    cfg.setup({ max_depth = 7 })
    local g = cfg.get()
    eq(7, g.max_depth)
    eq(vim.env.HOME .. "/.config/tmux-projects.txt", g.extra_file)
end

T["setup({}) is equivalent to no override"] = function()
    local cfg = require("tmux-projects.config")
    cfg.setup({})
    local g1 = cfg.get()
    helpers.reset_module()
    cfg = require("tmux-projects.config")
    local g2 = cfg.get()
    eq(g1.roots, g2.roots)
    eq(g1.extra_file, g2.extra_file)
    eq(g1.max_depth, g2.max_depth)
end

return T
