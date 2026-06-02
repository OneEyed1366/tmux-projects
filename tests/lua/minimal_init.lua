-- Mini-test setup: bootstrap mini.nvim and add the plugin (repo root) to rtp.
-- Intended for: `nvim --headless -u tests/lua/minimal_init.lua`

local data_dir = vim.fn.stdpath("data")
local mini_path = data_dir .. "/lazy/mini.nvim"
local plenary_path = data_dir .. "/lazy/plenary.nvim"
local telescope_path = data_dir .. "/lazy/telescope.nvim"

local function ensure_plugin(path, url)
    if vim.fn.isdirectory(path) == 1 then
        return
    end
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.system({ "git", "clone", "--depth=1", url, path })
end

ensure_plugin(mini_path, "https://github.com/echasnovski/mini.nvim")
ensure_plugin(plenary_path, "https://github.com/nvim-lua/plenary.nvim")
ensure_plugin(telescope_path, "https://github.com/nvim-telescope/telescope.nvim")

vim.opt.rtp:append(mini_path)
vim.opt.rtp:append(plenary_path)
vim.opt.rtp:append(telescope_path)

-- Sets the global `MiniTest` accessor.
require("mini.test").setup()

-- The plugin under test lives at the repo root (lua/ + plugin/).
-- Use the script's own location to find it. This is robust to whatever
-- cwd nvim is started from.
local this_script = debug.getinfo(1, "S").source:sub(2) -- strip leading "@"
local script_dir = vim.fn.fnamemodify(this_script, ":h")
local plugin_path = vim.fn.fnamemodify(script_dir .. "/../..", ":p"):gsub("/$", "")
vim.opt.rtp:append(plugin_path)

-- Also push to package.path explicitly as a belt-and-suspenders measure,
-- in case mini.test spawns child nvim processes that don't inherit rtp.
local lua_path = plugin_path .. "/lua/?.lua;" .. plugin_path .. "/lua/?/init.lua"
package.path = lua_path .. ";" .. package.path
