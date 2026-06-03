-- Shared UI helpers for picker actions. Kept thin so picker
-- actions stay focused on domain logic and don't reinvent
-- confirm/input dialogs.

local M = {}

-- Confirm-then-act helper. Calls on_yes() if the user picks "Yes".
-- Uses vim.ui.select (native Neovim UI; no extra deps).
function M.confirm(prompt, on_yes)
    vim.ui.select({ "Yes", "No" }, {
        prompt = prompt,
    }, function(choice)
        if choice == "Yes" then
            on_yes()
        end
    end)
end

return M
