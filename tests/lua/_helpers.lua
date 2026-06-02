-- Shared test helpers: require-cache reset, etc.

local M = {}

-- Force re-require of all our plugin modules so test-level setup() changes
-- take effect between cases. Telescope and plenary are left alone (they
-- don't carry per-test state we control).
function M.reset_module()
    for name, _ in pairs(package.loaded) do
        if name:match("^tmux%-projects") then
            package.loaded[name] = nil
        end
    end
end

return M
