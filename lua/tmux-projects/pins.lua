local M = {}

function M.read(extra_file)
    local f = io.open(extra_file, "r")
    if not f then
        return {}
    end
    local out = {}
    for line in f:lines() do
        local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed ~= "" and not trimmed:match("^#") then
            local cleaned = (trimmed:gsub("/$", ""))
            table.insert(out, cleaned)
        end
    end
    f:close()
    return out
end

function M.add(extra_file, p)
    p = p:gsub("/$", "")
    for _, existing in ipairs(M.read(extra_file)) do
        if existing == p then
            return
        end
    end
    local f = io.open(extra_file, "a")
    if not f then
        return
    end
    f:write(p .. "\n")
    f:close()
end

return M
