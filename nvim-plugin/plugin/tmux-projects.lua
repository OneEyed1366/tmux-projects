if vim.g.loaded_tmux_projects then
    return
end
vim.g.loaded_tmux_projects = true

vim.api.nvim_create_user_command("TmuxProjects", function()
    require("tmux-projects").open()
end, { desc = "Open tmux-projects picker" })

vim.api.nvim_create_user_command("TmuxKill", function()
    require("tmux-projects").kill()
end, { desc = "Kill tmux sessions (multi-select)" })
