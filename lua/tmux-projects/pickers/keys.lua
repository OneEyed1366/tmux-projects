-- Declarative keymap wiring for pickers. Extracts the boilerplate
-- from `attach_mappings` callbacks: get-the-selected-entry, notify-if-
-- empty, call-the-action, and bind the same key to BOTH the prompt
-- buffer (via telescope's `map`) and the results buffer (via
-- vim.keymap.set with `buffer = ...`).
--
-- Why extract: each action wrapper was ~7 lines (notify + call), and
-- the prompt/results duplication was 2 actions × 2 modes × 2 buffers
-- = 8 `vim.keymap.set` calls. Both halves are mechanical, so they're
-- ripe for a small declarative API. Adds 1 indirection layer, but
-- `pickers/open.lua` drops ~30 lines and the action→key wiring
-- becomes a single table literal.

local M = {}

local action_state = require("telescope.actions.state")

-- "get selected entry → notify if empty → call" preamble. Kills
-- the duplicated 7-line closures in open.lua.
local function with_selected_entry(prompt_bufnr, action_name, fn)
    local picked = action_state.get_selected_entry()
    if not picked then
        vim.notify("Nothing selected to " .. action_name, vim.log.levels.WARN)
        return
    end
    fn(picked.value)
end

-- Bind each (n_key, i_key, action_name, action_fn) to BOTH the
-- prompt buffer (via telescope's `map`) and the results buffer
-- (via `vim.keymap.set` with `buffer = ...`). The user can press
-- d/r from either focus; focus drift is the original reason for
-- the dual-buffer binding.
--
-- Caveats the caller used to inline (now live here, in one place):
--   * `<C-d>` in normal-mode `d` (vim muscle memory for `dd`).
--   * `<C-r>` in insert-mode `<C-r>` — overrides the default
--     "paste from register" in a regular text buffer (sacred
--     there) but in the picker prompt buffer it's a footgun:
--     an accidental `<C-r>` without a register name drops the
--     picker into a "waiting for register" state.
local function bind_one(map, action_name, action_fn, n_key, i_key)
    local wrapped = function()
        with_selected_entry(map, action_name, action_fn) -- map is just a sentinel; prompt_bufnr not needed here
    end
    map("n", n_key, wrapped)
    map("i", i_key, wrapped)
end

-- Public API. `bindings` is an array of { n_key, i_key, action_name,
-- action_fn } entries. Each entry is bound on both buffers.
function M.bind(prompt_bufnr, map, bindings)
    local function wrap(action_name, action_fn)
        return function()
            with_selected_entry(prompt_bufnr, action_name, action_fn)
        end
    end

    -- Prompt buffer (via telescope's `map`).
    for _, b in ipairs(bindings) do
        local w = wrap(b[3], b[4])
        map("n", b[1], w)
        map("i", b[2], w)
    end

    -- Results buffer (via vim.keymap.set). Focus drift between
    -- prompt and results buffers is the reason this dual-binding
    -- exists — see the long comment in pickers/open.lua (or the
    -- short version in this file's header).
    local picker = action_state.get_current_picker(prompt_bufnr)
    if picker and picker.results_bufnr and vim.api.nvim_buf_is_valid(picker.results_bufnr) then
        local results_bufnr = picker.results_bufnr
        for _, b in ipairs(bindings) do
            local w = wrap(b[3], b[4])
            vim.keymap.set("n", b[1], w, { buffer = results_bufnr, silent = true })
            vim.keymap.set("i", b[2], w, { buffer = results_bufnr, silent = true })
        end
    end
end

return M
