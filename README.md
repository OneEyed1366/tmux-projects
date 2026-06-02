# tmux-projects

A project switcher that fuses tmux, fzf, and Neovim. The bash and
Neovim sides share a pin file (`~/.config/tmux-projects.txt`) and a
session-naming rule, so a project pinned from the shell shows as
`★` in the Telescope picker and vice versa.

[![CI](https://github.com/OneEyed1366/tmux-projects/actions/workflows/ci.yml/badge.svg)](https://github.com/OneEyed1366/tmux-projects/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Demo

```text
$ tmux-sessionizer
  ● main
  ★ /Users/me/projects/tmux-projects
  + /Users/me/personal/dotfiles
  /Users/me/projects/ronnie-ide
  /Users/me/personal/wolf-tui
project> tmux
  ● main
> ★ /Users/me/projects/tmux-projects
  + /Users/me/personal/dotfiles
  /Users/me/projects/ronnie-ide
  /Users/me/personal/wolf-tui
project> tmux_
# (Enter — switches into the existing tmux session, nvim state intact)

$ tmux-sessionizer --validate
OK tmux=tmux fzf=/opt/homebrew/bin/fzf fd=/opt/homebrew/bin/fd
OK roots=/Users/me/projects /Users/me/personal
OK extra_file=/Users/me/.config/tmux-projects.txt
```

In Neovim, the same flow lands in a Telescope picker:

```text
:lua require("tmux-projects").open()
┌─ tmux projects ─────────────────────────────────┐
│ ● main                                           │
│ ★ /Users/me/projects/tmux-projects               │
│ + /Users/me/personal/dotfiles                    │
│   /Users/me/projects/ronnie-ide                  │
│   /Users/me/personal/wolf-tui                    │
└──────────────────────────────────────────────────┘
```

`★` is a pinned project from `~/.config/tmux-projects.txt`. `●` is a
live tmux session. Other entries are auto-discovered project roots
(any dir under your configured roots containing a `.git`, plus their
direct children).

## Requirements

- bash 4+
- tmux 3+
- fzf
- fd
- Neovim 0.10+ and `nvim-telescope/telescope.nvim` (for the plugin side)

## Permissions

Spawns `tmux new-session` and runs `nvim` inside the new session.
Creates `~/.config/tmux-projects.txt` on first "Browse for folder…".
**No network calls, no telemetry, no modifications to your nvim /
tmux / shell configs, no writes inside the projects you switch into.**
Full trust model: [`SECURITY.md`](SECURITY.md). Reversibility:
`./uninstall.sh` (or `make uninstall`).

## Installation

### Shell (bash + fzf)

```bash
git clone https://github.com/OneEyed1366/tmux-projects.git
cd tmux-projects
./install.sh          # or: make install
```

Verify:

```bash
tmux-sessionizer --version
tmux-sessionizer --validate
```

### Neovim plugin (`tmux-projects.nvim`)

#### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "OneEyed1366/tmux-projects",
    dir   = "nvim-plugin",                  -- omit if installed as a public package
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
        require("tmux-projects").setup({})
    end,
}
```

#### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "OneEyed1366/tmux-projects",
    config = function() require("tmux-projects").setup({}) end,
}
```

#### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'OneEyed1366/tmux-projects'
" then in init.lua:
lua require('tmux-projects').setup({})
```

The plugin must run inside tmux; it exits early with a warning
otherwise.

## Setup

### Bash

```bash
tmux-sessionizer
```

That's it — fzf popup, pick, switch.

### Neovim

```lua
require("tmux-projects").setup({})   -- see Configuration
```

```vim
:TmuxProjects                        " open the picker
:TmuxKill                            " multi-select kill picker
:lua require("tmux-projects").open() " same as :TmuxProjects
:lua require("tmux-projects").kill() " same as :TmuxKill
```

Suggested keybinding (in your which-key / config):

```lua
{ "<leader>p",  function() require("tmux-projects").open() end, desc = "Switch project" },
{ "<leader>kp", function() require("tmux-projects").kill() end, desc = "Kill project sessions" },
```

## Why

If you've used [ThePrimeagen's tmux-sessionizer][primeagen],
[telescope-project.nvim][telescope-project], or [Harpoon][harpoon], the
shape is familiar. What's new here is the **symmetry contract**: the
bash script and the nvim plugin read the same pin file, use the same
session-naming rule, and produce the same UI markers
(`★` / `●` / `+`). Pin a project from either surface, see it in the
other. The contract is enforced by tests on both sides — divergence
is a CI failure, not a user-visible surprise.

[primeagen]: https://github.com/ThePrimeagen/tmux-sessionizer
[telescope-project]: https://github.com/nvim-telescope/telescope-project.nvim
[harpoon]: https://github.com/ThePrimeagen/harpoon

## Configuration

### Runtime options

All runtime options are configurable in two ways — env var for the
bash side, `setup{}` table for the nvim plugin. Both sides share the
same defaults. Where both sides support an option, they have the same
semantics.

| Option | bash env var | nvim `setup{}` key | Type | Default | Notes |
|---|---|---|---|---|---|
| Project roots | `TMUX_SESSIONIZER_ROOTS` | `roots` | string (colon-sep) / table | `$HOME/projects:$HOME/personal` | Tilde-expanded. Each entry is scanned for `.git` roots and direct children. `roots` is a **sequence** — replaced wholesale, not deep-merged with defaults. |
| Pins file | `TMUX_SESSIONIZER_EXTRA_FILE` | `extra_file` | string | `$HOME/.config/tmux-projects.txt` | Created on first use of "Browse for folder…". Read by both sides. |
| Browse label | `TMUX_SESSIONIZER_BROWSE_LABEL` | `browse_label` | string | `+ Browse for folder…` | Label of the OS-folder-picker entry in the list. |
| fzf prompt | `TMUX_SESSIONIZER_PROMPT` | — | string | `project> ` | Bash only. The nvim plugin uses a hardcoded Telescope prompt title. |
| Max scan depth | `TMUX_SESSIONIZER_MAX_DEPTH` | `max_depth` | integer | `5` | How deep `fd` looks for `.git` under each root. Lower = faster on huge monorepos. |

#### Bash examples

```bash
# ~/.zshrc or ~/.bashrc
export TMUX_SESSIONIZER_ROOTS="$HOME/Code:$HOME/personal"
export TMUX_SESSIONIZER_PROMPT="❯ "

# WSL: use Linux paths
export TMUX_SESSIONIZER_ROOTS="/home/me/projects:/home/me/work"

# Monorepos: shallow scan
export TMUX_SESSIONIZER_MAX_DEPTH=3
```

#### Nvim examples

```lua
-- Minimal (use defaults)
require("tmux-projects").setup({})

-- With overrides
require("tmux-projects").setup({
    roots        = { "/Users/me/Code", "/Users/me/work" },
    max_depth    = 6,
    browse_label = "+ Pick a project…",
})

-- Extend the default roots rather than replace them
require("tmux-projects").setup({
    roots = vim.list_extend({
        vim.env.HOME .. "/projects",
        vim.env.HOME .. "/personal",
    }, { vim.env.HOME .. "/Code" }),
})
```

### Install-time options

`install.sh` and `make install` accept three paths:

| Flag | env var | Default | Purpose |
|---|---|---|---|
| `--prefix DIR` | `PREFIX` | `~/.local` | Root of the install. |
| `--bindir DIR` | `BINDIR` | `$PREFIX/bin` | Where `tmux-sessionizer` lands. |
| `--libdir DIR` | `LIBDIR` | `$PREFIX/lib` | Where `tmux-sessionizer.sh` (the helper lib) lands. |

```bash
sudo PREFIX=/usr/local ./install.sh               # system-wide
./install.sh --prefix /opt/tmux-projects         # custom layout
make install PREFIX=/usr/local                   # via Makefile
```

### Pin file

`~/.config/tmux-projects.txt` — one absolute path per line. `#` is a
comment, blank lines are ignored, trailing slashes are stripped.

```text
# ~/projects
/Users/me/projects/foo
/Users/me/projects/bar

# ~/personal
/Users/me/personal/dotfiles
```

Full spec (session-naming rule, dedup, symmetry contract): [`share/SPEC.md`](share/SPEC.md).

### Tmux integration

```tmux
# ~/.tmux.conf
bind p display-popup -E "tmux-sessionizer"
# or, if you'd rather not pollute the prefix table:
bind -T prefix P display-popup -E "tmux-sessionizer"
```

When tmux spawns a popup it uses a minimal PATH. The script exports
`/opt/homebrew/bin:/opt/homebrew/sbin:$HOME/.local/bin` ahead of PATH
so `fzf`, `fd`, and `nvim` are findable in the popup. If your tools
live elsewhere, extend PATH in your shell rc before running tmux.

### Spawned shell

New sessions run an interactive login shell with `nvim` as the initial
command, dropping back to the shell on exit:

```bash
${SHELL:-/bin/zsh} -ilc 'nvim; exec ${SHELL:-/bin/zsh} -il'
```

`$SHELL` is honored. `-i -l` (interactive + login) is required so
`~/.zshrc` / `~/.bashrc` runs — without it, `nvm` / `pyenv` / `asdf`
won't be on PATH and LSPs in nvim crash. To change the initial
command (e.g., to `emacs` or `helix`), edit `bin/tmux-sessionizer` —
search for `nvim; exec` in the `tmux new-session` line. There is no
env override; the spawned command is intentionally script-level
because it affects session semantics.

The script always passes `-L <socket>` to `tmux` so it talks to the
right per-window server when running inside Ghostty-tmux (or any
multi-server setup). The socket name is read from `$TMUX_SOCKET` or
parsed out of `$TMUX`. Automatic.

## Default mappings

### fzf popup (bash)

The script uses fzf defaults. To override, pass `--bind` flags via
your own wrapper or by editing `bin/tmux-sessionizer`.

| Key | Action |
| --- | ------ |
| `Enter` | Open / switch to selected project |
| `Ctrl-C` / `Esc` | Cancel |

### Telescope picker (nvim)

The plugin overrides the default `select_default` action (Enter). All
other Telescope defaults apply.

| Mode | Key | Action |
| ---- | --- | ------ |
| n | `<CR>` | Open / switch to selected project |
| n | `i` | Toggle insert mode for live filtering |
| n | `<C-c>` | Close picker |
| i | `<CR>` | Same as `<CR>` in normal mode (via Telescope default) |
| i | `<C-c>` | Close picker |

## Available functions

### Bash CLI

| Command | Effect |
|---|---|
| `tmux-sessionizer` | Open fzf picker, switch to / create session |
| `tmux-sessionizer --version` | Print version |
| `tmux-sessionizer --help` | Full help text |
| `tmux-sessionizer --validate` | Smoke-check deps + config; exit 0 if OK |

### Neovim

| Function / command | Effect |
|---|---|
| `require("tmux-projects").setup({...})` | Configure the plugin (call once at startup) |
| `require("tmux-projects").open()` | Open the picker |
| `require("tmux-projects").kill()` | Multi-select kill picker |
| `:TmuxProjects` | Same as `.open()` |
| `:TmuxKill` | Same as `.kill()` |

## Uninstall

```bash
./uninstall.sh        # or: make uninstall
```

Removes `~/.local/bin/tmux-sessionizer` and
`~/.local/lib/tmux-sessionizer.sh`. The pin file
`~/.config/tmux-projects.txt` is **left in place** — delete it manually
if you want a clean slate. The plugin spec in your nvim config
(`require("tmux-projects")` entry) is also yours to remove.

## Roadmap

- [x] bash + fzf + tmux sessionizer
- [x] nvim plugin with Telescope picker
- [x] shared pin file + session-naming contract (symmetry)
- [x] install.sh + uninstall.sh + Makefile
- [x] GitHub Actions CI (shellcheck, stylua, bats, mini.test)
- [x] 62 tests (34 bats + 28 mini.test) covering the contract
- [x] v0.1.0 release
- [ ] Homebrew formula
- [ ] luarocks release for the plugin
- [ ] Auto-pinning heuristic for active projects
- [ ] lualine / statusline integration (show current project)
- [ ] Optional fzf `--bind` for "+ Browse" hotkey (skip the picker)

## Contributing

Issues and PRs welcome. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for
the workflow, contract discipline, and Conventional Commits
convention. Before opening a PR:

```bash
make lint     # shellcheck + stylua
make test     # bats + mini.test
```

## License

MIT — see [`LICENSE`](LICENSE).
