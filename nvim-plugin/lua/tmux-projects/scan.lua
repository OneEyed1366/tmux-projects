local M = {}

local function is_dir(p)
    local st = vim.uv.fs_stat(p)
    return st and st.type == "directory"
end

function M.scanned_dirs(roots, max_depth)
    local existing = {}
    for _, r in ipairs(roots) do
        if is_dir(r) then
            table.insert(existing, r)
        end
    end
    if #existing == 0 then
        return {}
    end

    local set = {}

    local git_args = { "fd", "--hidden", "--type", "d", "--max-depth", tostring(max_depth), "^\\.git$" }
    vim.list_extend(git_args, existing)
    local r1 = vim.system(git_args, { text = true }):wait()
    for line in (r1.stdout or ""):gmatch("[^\r\n]+") do
        local trimmed = line:gsub("/%.git/?$", "")
        if trimmed ~= "" then
            set[trimmed] = true
        end
    end

    local top_args = { "fd", "--type", "d", "--max-depth", "1", "--min-depth", "1", "." }
    vim.list_extend(top_args, existing)
    local r2 = vim.system(top_args, { text = true }):wait()
    for line in (r2.stdout or ""):gmatch("[^\r\n]+") do
        local trimmed = line:gsub("/$", "")
        if trimmed ~= "" then
            set[trimmed] = true
        end
    end

    local out = {}
    for k in pairs(set) do
        table.insert(out, k)
    end
    table.sort(out)
    return out
end

return M
