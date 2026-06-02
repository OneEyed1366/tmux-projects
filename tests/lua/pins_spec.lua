-- Tests for tmux-projects.pins — read/dedupe/add using real temp files.

local this_file = debug.getinfo(1, "S").source:sub(2)
local helpers = dofile(vim.fn.fnamemodify(this_file, ":h") .. "/_helpers.lua")
local new_set, eq = MiniTest.new_set, MiniTest.expect.equality

local pins = require("tmux-projects.pins")

local T = new_set({ hooks = { pre_case = helpers.reset_module } })

local function write_pins(path, lines)
    local f = io.open(path, "w")
    f:write(table.concat(lines, "\n") .. "\n")
    f:close()
end

T["read: missing file → empty list"] = function()
    local p = vim.fn.tempname()
    eq({}, pins.read(p))
end

T["read: simple one-path file"] = function()
    local p = vim.fn.tempname()
    write_pins(p, { "/Users/me/projects/foo" })
    eq({ "/Users/me/projects/foo" }, pins.read(p))
end

T["read: ignores # comments"] = function()
    local p = vim.fn.tempname()
    write_pins(p, {
        "# comment",
        "/Users/me/projects/foo",
        "# /Users/me/commented",
        "/Users/me/personal/bar",
    })
    eq({ "/Users/me/projects/foo", "/Users/me/personal/bar" }, pins.read(p))
end

T["read: ignores blank lines"] = function()
    local p = vim.fn.tempname()
    write_pins(p, {
        "/Users/me/projects/foo",
        "",
        "/Users/me/personal/bar",
        "",
    })
    eq({ "/Users/me/projects/foo", "/Users/me/personal/bar" }, pins.read(p))
end

T["read: strips trailing slashes"] = function()
    local p = vim.fn.tempname()
    write_pins(p, { "/Users/me/projects/foo/" })
    eq({ "/Users/me/projects/foo" }, pins.read(p))
end

T["read: indented # is still a comment"] = function()
    local p = vim.fn.tempname()
    write_pins(p, {
        "   # leading-whitespace comment",
        "/Users/me/foo",
    })
    eq({ "/Users/me/foo" }, pins.read(p))
end

T["add: appends new path to empty file"] = function()
    local p = vim.fn.tempname()
    pins.add(p, "/Users/me/new")
    eq({ "/Users/me/new" }, pins.read(p))
end

-- почему: DEDUP IS THE CONTRACT. Same as bash `add_pin` idempotent
-- test. A pinned path must appear exactly once in the file
-- regardless of how many times add() is called. Violation =
-- duplicate `★` markers in the picker = same project listed twice.
T["add: idempotent — second add of same path is no-op"] = function()
    local p = vim.fn.tempname()
    pins.add(p, "/Users/me/foo")
    pins.add(p, "/Users/me/foo")
    pins.add(p, "/Users/me/foo")
    eq({ "/Users/me/foo" }, pins.read(p))
end

T["add: different paths accumulate"] = function()
    local p = vim.fn.tempname()
    pins.add(p, "/Users/me/a")
    pins.add(p, "/Users/me/b")
    pins.add(p, "/Users/me/c")
    eq({ "/Users/me/a", "/Users/me/b", "/Users/me/c" }, pins.read(p))
end

T["add: trailing-slash path matches slashless existing"] = function()
    local p = vim.fn.tempname()
    pins.add(p, "/Users/me/foo")
    pins.add(p, "/Users/me/foo/")
    eq({ "/Users/me/foo" }, pins.read(p))
end

return T
