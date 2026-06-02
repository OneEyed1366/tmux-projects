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

-- Remove <p> from the pin file. Idempotent: returns false (not an
-- error) when the path wasn't pinned.
-- Line-preserving: comments, blank lines, and surrounding whitespace
-- of surviving entries are written through verbatim. The pin file
-- is the user's curated hide list — silently dropping their `#`
-- annotations on every delete would be data loss.
-- Atomic via temp + os_rename: a crash mid-rewrite leaves the
-- original file intact, not half-written.
function M.remove(extra_file, p)
    p = (p:gsub("/$", ""))
    if vim.uv.fs_stat(extra_file) == nil then
        return false
    end

    local src = io.open(extra_file, "r")
    if not src then
        return false
    end

    local tmp_path = extra_file .. ".tmp." .. tostring(vim.uv.hrtime())
    local tmp, err = io.open(tmp_path, "w")
    if not tmp then
        src:close()
        error("pins.remove: cannot open temp file: " .. tostring(err))
    end

    local removed = false
    for line in src:lines() do
        -- Strip leading/trailing whitespace and a trailing slash,
        -- mirroring the read() contract.
        local trimmed = line:gsub("^%s+", ""):gsub("%s+$", ""):gsub("/$", "")
        if trimmed == p then
            removed = true
        else
            tmp:write(line)
            tmp:write("\n")
        end
    end
    src:close()
    tmp:close()

    if not removed then
        os.remove(tmp_path)
        return false
    end

    local ok, rename_err = os.rename(tmp_path, extra_file)
    if not ok then
        os.remove(tmp_path)
        error("pins.remove: rename failed: " .. tostring(rename_err))
    end
    return true
end

return M
