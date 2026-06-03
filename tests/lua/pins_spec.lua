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

-- почему: removal = dedup's mirror. If the picker lets users pin a
-- path but never unpin it, the "delete project" picker action is a
-- lie. The pin file must shrink on remove or stale entries haunt
-- the picker.
T["remove: removes the target path"] = function()
    local p = vim.fn.tempname()
    pins.add(p, "/Users/me/a")
    pins.add(p, "/Users/me/b")
    pins.add(p, "/Users/me/c")
    eq(true, pins.remove(p, "/Users/me/b"))
    eq({ "/Users/me/a", "/Users/me/c" }, pins.read(p))
end

-- почему: removing the only entry should leave an empty file (not
-- delete the file). The picker reads PINS=[] from a missing or empty
-- file, but the file's existence vs. absence is observable to other
-- tools (e.g. `--validate` checks the dir). Preserve the file.
T["remove: removes the only entry, file stays empty"] = function()
    local p = vim.fn.tempname()
    pins.add(p, "/Users/me/solo")
    eq(true, pins.remove(p, "/Users/me/solo"))
    eq(1, vim.fn.filereadable(p))
    eq({}, pins.read(p))
    local f = io.open(p, "r")
    eq("", f:read("*a"))
    f:close()
end

-- почему: the picker action is idempotent UX-wise — pressing `d`
-- on a project that's already gone must not error. The contract:
-- silent no-op returning false. Violation = an error toast every
-- time the user clicks an already-deleted row.
T["remove: idempotent — removing an absent path returns false"] = function()
    local p = vim.fn.tempname()
    eq(false, pins.remove(p, "/Users/me/never-pinned"))
end

-- почему: unpin on a never-created file (e.g. user has never
-- browsed) must not error and must not create the file. Creating
-- an empty file here would be a side effect with no caller asking
-- for it.
T["remove: missing file is a silent no-op"] = function()
    local p = vim.fn.tempname()
    eq(false, pins.remove(p, "/Users/me/anything"))
    eq(0, vim.fn.filereadable(p))
end

-- почему: same slash-stripping contract as add. The picker stores
-- paths slashless; if remove didn't strip, the user's `d` action
-- on a path added via the OS picker (which may give `/foo/`) would
-- silently fail to match. See add:trailing-slash test for the
-- symmetric case.
T["remove: trailing-slash path matches slashless existing"] = function()
    local p = vim.fn.tempname()
    pins.add(p, "/Users/me/foo")
    eq(true, pins.remove(p, "/Users/me/foo/"))
    eq({}, pins.read(p))
end

-- почему: comments and blank lines must survive remove. A naive
-- rewrite that only writes parsed paths would erase user comments
-- — silent data loss on every delete.
T["remove: preserves comments and blank lines in the file"] = function()
    local p = vim.fn.tempname()
    write_pins(p, {
        "# my curated list",
        "/Users/me/foo",
        "",
        "# /Users/me/commented-out",
        "/Users/me/bar",
    })
    eq(true, pins.remove(p, "/Users/me/foo"))
    eq({ "/Users/me/bar" }, pins.read(p))
    local f = io.open(p, "r")
    local contents = f:read("*a")
    f:close()
    -- Header comment must still be there.
    assert(contents:find("# my curated list", 1, true), "lost header comment")
    -- Surrounding comment must still be there.
    assert(contents:find("# /Users/me/commented-out", 1, true), "lost surrounding comment")
    -- Blank line preserved.
    assert(contents:find("\n\n", 1, true), "lost blank line")
end

-- почему: pin files written by external tools (or hand-edited in
-- editors that don't auto-add a trailing newline) may lack a final
-- `\n`. Default `*l` iterator silently drops the unterminated last
-- line, which would erase the user's last entry on every delete.
-- This test pins the data-loss fix: surviving entries — including
-- the unterminated last one — must round-trip through remove().
--
-- Byte-exact: the file must be EXACTLY the expected bytes (no
-- trailing newline added, none dropped). Without `eq` on the raw
-- bytes, a future regression that "normalizes" the file (adds a
-- `\n`) would pass content checks via pins.read but still be a
-- contract violation per share/SPEC.md.
T["remove: preserves file's trailing-newline state (no newline)"] = function()
    local p = vim.fn.tempname()
    local f = io.open(p, "wb")
    f:write("/Users/me/a\n/Users/me/b") -- no final \n
    f:close()
    eq(true, pins.remove(p, "/Users/me/a"))
    eq({ "/Users/me/b" }, pins.read(p))
    local f2 = io.open(p, "rb")
    local contents = f2:read("*a")
    f2:close()
    eq("/Users/me/b", contents) -- exactly, no trailing newline
end

-- почему: symmetric case — file with trailing newline must keep
-- it after remove. The rewrite contract in share/SPEC.md: "A
-- file with one keeps one." Mirrors the parallel bash test.
T["remove: preserves file's trailing-newline state (with newline)"] = function()
    local p = vim.fn.tempname()
    local f = io.open(p, "wb")
    f:write("/Users/me/a\n/Users/me/b\n") -- has final \n
    f:close()
    eq(true, pins.remove(p, "/Users/me/a"))
    eq({ "/Users/me/b" }, pins.read(p))
    local f2 = io.open(p, "rb")
    local contents = f2:read("*a")
    f2:close()
    eq("/Users/me/b\n", contents) -- exactly, with trailing newline
end

return T
