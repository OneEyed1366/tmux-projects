local M = {}

local config = require("tmux-projects.config")
local tmux = require("tmux-projects.tmux")
local scan = require("tmux-projects.scan")
local pins = require("tmux-projects.pins")
local native = require("tmux-projects.pickers.native")

local function build_entries()
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

local function open_project(path)
    path = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
    local name = tmux.path_to_session_name(path)

    local r = vim.system(tmux.cmd("has-session", "-t=" .. name), { text = true }):wait()
    if r.code ~= 0 then
        local shell = vim.env.SHELL or "/bin/zsh"
        local inner = shell .. " -ilc 'nvim; exec " .. shell .. " -il'"
        local create = vim.system(tmux.cmd("new-session", "-ds", name, "-c", path, inner), { text = true }):wait()
        if create.code ~= 0 then
            vim.notify("tmux new-session failed: " .. (create.stderr or ""), vim.log.levels.ERROR)
            return
        end
    end

    local cmd = (vim.env.TMUX and vim.env.TMUX ~= "") and "switch-client" or "attach"
    vim.system(tmux.cmd(cmd, "-t", name)):wait()
end

local function attach_to_existing_session(name)
    local cmd = (vim.env.TMUX and vim.env.TMUX ~= "") and "switch-client" or "attach"
    vim.system(tmux.cmd(cmd, "-t", name)):wait()
end

function M.open()
    if not (vim.env.TMUX and vim.env.TMUX ~= "") then
        vim.notify("Not running inside tmux", vim.log.levels.WARN)
        return
    end
    local ok = pcall(require, "telescope")
    if not ok then
        vim.notify("telescope.nvim not loaded", vim.log.levels.ERROR)
        return
    end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local cfg = config.get()
    local entries = build_entries()

    pickers
        .new({}, {
            prompt_title = "tmux projects",
            finder = finders.new_table({
                results = entries,
                entry_maker = function(e)
                    return {
                        value = e,
                        display = e.label,
                        ordinal = e.label,
                    }
                end,
            }),
            sorter = conf.generic_sorter({}),
            layout_strategy = "vertical",
            attach_mappings = function(prompt_bufnr, _)
                actions.select_default:replace(function()
                    local picked = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if not picked then
                        return
                    end
                    local e = picked.value

                    if e.kind == "live" then
                        attach_to_existing_session(e.name)
                    elseif e.kind == "browse" then
                        vim.schedule(function()
                            local chosen = native.pick_folder()
                            if not chosen or chosen == "" then
                                return
                            end
                            chosen = chosen:gsub("/$", "")
                            pins.add(cfg.extra_file, chosen)
                            open_project(chosen)
                        end)
                    elseif e.kind == "pinned" or e.kind == "scanned" then
                        open_project(e.path)
                    end
                end)
                return true
            end,
        })
        :find()
end

return M
