-- Build the picker entry list. Pure function — reads config + the
-- pin file + invokes `tmux list-sessions` and `fd` for scanning.
-- Returns an array of entries the picker can render directly.

local M = {}

local config = require("tmux-projects.config")
local tmux = require("tmux-projects.tmux")
local scan = require("tmux-projects.scan")
local pins = require("tmux-projects.pins")

function M.build()
    local cfg = config.get()
    local entries = { { kind = "browse", label = cfg.browse_label } }

    local live = tmux.live_sessions()
    local live_set = {}
    for _, s in ipairs(live) do
        live_set[s] = true
        table.insert(entries, { kind = "live", label = "● " .. s, name = s })
    end

    for _, p in ipairs(pins.read(cfg.extra_file)) do
        local sess = tmux.path_to_session_name(p)
        if not live_set[sess] then
            table.insert(entries, { kind = "pinned", label = "★ " .. p, path = p })
        end
    end

    for _, p in ipairs(scan.scanned_dirs(cfg.roots, cfg.max_depth)) do
        local sess = tmux.path_to_session_name(p)
        if not live_set[sess] then
            table.insert(entries, { kind = "scanned", label = "  " .. p, path = p })
        end
    end

    return entries
end

return M
