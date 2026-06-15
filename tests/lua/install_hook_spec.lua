local new_set = MiniTest.new_set

local T = new_set({})

local function repo_root()
	local this_file = debug.getinfo(1, "S").source:sub(2)
	local spec_dir = vim.fn.fnamemodify(this_file, ":h")
	return vim.fn.fnamemodify(spec_dir .. "/../..", ":p"):gsub("/$", "")
end

local function read_file(path)
	local lines = vim.fn.readfile(path)
	return table.concat(lines, "\n")
end

T["lazy.nvim: repo provides a build hook that runs install.sh"] = function()
	local root = repo_root()
	local build_lua = root .. "/build.lua"
	assert(vim.uv.fs_stat(build_lua), "expected build.lua at repo root")

	local content = read_file(build_lua)
	assert(content:match("install%.sh"), "expected build.lua to reference install.sh")
end

T["README: plugin manager snippets wire install.sh"] = function()
	local readme = read_file(repo_root() .. "/README.md")

	assert(readme:match('build%s*=%s*"%.?/install%.sh"'), "expected lazy.nvim snippet to run install.sh")
	assert(readme:match('run%s*=%s*"%.?/install%.sh"'), "expected packer.nvim snippet to run install.sh")
	assert(readme:match("Plug 'OneEyed1366/tmux%-projects', %b{}"), "expected vim-plug snippet options")
	assert(readme:match("'do': '%./install%.sh'"), "expected vim-plug snippet to run install.sh")
end

return T
