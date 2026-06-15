local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")

local result = vim.system({ "bash", "./install.sh" }, {
    cwd = root,
    text = true,
}):wait()

if result.code ~= 0 then
    error((result.stderr and result.stderr ~= "" and result.stderr) or "install.sh failed")
end
