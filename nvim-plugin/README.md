# tmux-projects.nvim

Native Neovim + Telescope picker for the [tmux-projects](../) workflow.

> Up to date with the monorepo at `OneEyed1366/tmux-projects`. This README
> focuses on the nvim-plugin component — for the bash side, see the
> [top-level README](../README.md).

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "OneEyed1366/tmux-projects",
    dir   = "nvim-plugin",  -- omit if installed as a public package
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
        require("tmux-projects").setup({})
    end,
}
```

Requires: **Neovim 0.10+**, `telescope.nvim`. The picker must run inside
tmux; it exits early with a warning otherwise.

<details>
<summary>Other plugin managers</summary>

**packer.nvim:**

```lua
use {
    "OneEyed1366/tmux-projects",
    config = function() require("tmux-projects").setup({}) end,
}
```

**vim-plug:**

```vim
Plug 'OneEyed1366/tmux-projects'
" then in init.lua:
lua require('tmux-projects').setup({})
```

</details>

## Usage

```text
:lua require("tmux-projects").open()
┌─ tmux projects ──────────────────────────────────────┐
│ ● main                                                │
│ ★ /Users/me/projects/tmux-projects                    │
│ + /Users/me/personal/dotfiles                         │
│   /Users/me/projects/ronnie-ide                       │
│   /Users/me/personal/wolf-tui                         │
└───────────────────────────────────────────────────────┘
```

Pick an entry:

- `● name` — already a live tmux session; switch to it.
- `★ /path` — pinned in `~/.config/tmux-projects.txt`; create the
  session if it doesn't exist, then switch.
- `  /path` — auto-discovered project (`.git` root or top-level dir under
  `ROOTS`); same behavior as `★`.
- `+ Browse for folder…` — open the native OS folder picker (osascript /
  zenity / kdialog). The chosen path is auto-pinned and opened.

`:TmuxKill` (or `require("tmux-projects").kill()"`) opens a multi-select
picker for killing tmux sessions. Tab to multi-select, Enter to kill.

### Suggested which-key bindings

```lua
{
    "<leader>p",
    function() require("tmux-projects").open() end,
    desc = "Switch project (tmux)",
},
{
    "<leader>kp",
    function() require("tmux-projects").kill() end,
    desc = "Kill project sessions (tmux)",
},
```

## Configuration

`require("tmux-projects").setup({ ... })` accepts a table. All keys are
optional; defaults match the bash side.

| Key | Type | Default | Description |
|---|---|---|---|
| `roots` | `string[]` | `{ vim.env.HOME .. "/projects", vim.env.HOME .. "/personal" }` | Directories scanned for `.git` roots + top-level children |
| `extra_file` | `string` | `~/.config/tmux-projects.txt` | Pinned projects file (shared with bash) |
| `browse_label` | `string` | `"+ Browse for folder…"` | Label for the folder-picker entry |
| `max_depth` | `number` | `5` | How deep to look for `.git` dirs under each root |

Example:

```lua
require("tmux-projects").setup({
    roots     = { "/Users/me/Code", "/Users/me/work" },
    max_depth = 6,
})
```

## The contract with the bash side

This plugin and `bin/tmux-sessionizer` MUST agree on:

- **Pin file format.** Both read `~/.config/tmux-projects.txt` with the
  same parser (one path per line, `#` comments, blank lines ignored,
  trailing slashes stripped).
- **Session naming.** Both apply the same `path_to_session_name` rule
  (basename, drop leading dot, replace ` ` `.` `:` `/` with `_`).
- **Pinned-vs-live dedup.** Both hide `★` entries whose session is
  already live (so you don't see the same project twice).

If the contract breaks, the same project gets two different tmux
sessions depending on which UI you used. Tests in
[`tests/lua/`](../tests/lua/) and [`tests/bash/`](../tests/bash/) catch
this — divergence is a CI failure, not a user-visible surprise.

## Trust

- No network calls. No telemetry.
- The plugin reads the pin file and writes to it (only when you
  `+ Browse for folder…` and pick a directory).
- It calls `tmux` to query and switch sessions — the same commands
  you'd run by hand.
- It does not modify your nvim config, your tmux config, or any
  project file.

## License

MIT — see [LICENSE](../LICENSE).
