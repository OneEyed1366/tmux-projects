local M = {}

local function try(cmd)
    local r = vim.system(cmd, { text = true }):wait()
    if r.code == 0 then
        local out = (r.stdout or ""):gsub("[\r\n]+$", "")
        if out ~= "" then
            return out
        end
    end
end

function M.pick_folder()
    if vim.fn.executable("osascript") == 1 then
        return try({
            "osascript",
            "-e",
            'POSIX path of (choose folder with prompt "Pick a project folder to pin")',
        })
    elseif vim.fn.executable("zenity") == 1 then
        return try({
            "zenity",
            "--file-selection",
            "--directory",
            "--title=Pick a project folder to pin",
        })
    elseif vim.fn.executable("kdialog") == 1 then
        return try({
            "kdialog",
            "--getexistingdirectory",
            vim.env.HOME,
            "--title",
            "Pick a project folder to pin",
        })
    end
    return nil
end

return M
