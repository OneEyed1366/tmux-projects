local M = {}

local tmux = require("tmux-projects.tmux")

function M.kill()
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
    local action_utils = require("telescope.actions.utils")

    local current = vim.system(tmux.cmd("display-message", "-p", "#S"), { text = true }):wait().stdout or ""
    current = current:gsub("[\r\n]+$", "")

    local sessions = {}
    for _, s in ipairs(tmux.live_sessions()) do
        if s ~= current then
            table.insert(sessions, s)
        end
    end
    if #sessions == 0 then
        vim.notify("No other sessions to kill (current: " .. current .. ")", vim.log.levels.INFO)
        return
    end

    pickers
        .new({}, {
            prompt_title = "kill tmux sessions  (Tab to multi-select)",
            finder = finders.new_table({
                results = sessions,
                entry_maker = function(s)
                    return { value = s, display = "● " .. s, ordinal = s }
                end,
            }),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, _)
                actions.select_default:replace(function()
                    local picks = {}
                    action_utils.map_selections(prompt_bufnr, function(entry)
                        table.insert(picks, entry.value)
                    end)
                    if #picks == 0 then
                        local sel = action_state.get_selected_entry()
                        if sel then
                            table.insert(picks, sel.value)
                        end
                    end
                    actions.close(prompt_bufnr)
                    for _, s in ipairs(picks) do
                        vim.system(tmux.cmd("kill-session", "-t", s)):wait()
                    end
                    if #picks > 0 then
                        vim.notify(
                            "Killed " .. #picks .. " session(s): " .. table.concat(picks, ", "),
                            vim.log.levels.INFO
                        )
                    end
                end)
                return true
            end,
        })
        :find()
end

return M
