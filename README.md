<div align="center">

# tmux-projects

### Switching projects shouldn't mean losing your editor state.

[![CI](https://github.com/OneEyed1366/tmux-projects/actions/workflows/ci.yml/badge.svg)](https://github.com/OneEyed1366/tmux-projects/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A project switcher that fuses tmux, fzf, and Neovim. Pin once, see the same
`★` in both the shell popup and the nvim picker, land in the same tmux
session with your buffers still warm.

[Install](#install) · [How it works](#how-it-works) · [Configuration](#configuration) · [Reference](share/SPEC.md)

</div>

---

> [!IMPORTANT]
> **What it touches**
>
> - `tmux new-session` to spawn a session for a new project (you set the shell that runs in it)
> - `nvim` inside that session (no magic — just a shell + nvim)
> - `~/.config/tmux-projects.txt` — created on first use of "Browse for folder…", append-only
>
> **What it does NOT do**
>
> - No network calls. No telemetry. No analytics.
> - No modifications to your nvim config, your tmux config, or your shell rc.
> - No writes inside the projects you switch into.
>
> **Reversibility**
>
> ```bash
> ./uninstall.sh        # or: make uninstall
> # Removes both installed files. Your pin file is left in place; delete it manually if you want.
> ```

---

## Install

Pick the surface you need — they share the same pin file and session names.

### Shell (bash + fzf)

```bash
git clone https://github.com/OneEyed1366/tmux-projects.git
cd tmux-projects
./install.sh           # or: make install
```

Verify:

```bash
tmux-sessionizer --version
tmux-sessionizer --validate
```

Requires: `bash 4+`, `tmux 3+`, `fzf`, `fd`. macOS, Linux, and WSL are supported.

### Neovim (`tmux-projects.nvim`)

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "OneEyed1366/tmux-projects",
    dir   = "nvim-plugin",                  -- omit if installed as a public package
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
        require("tmux-projects").setup({})  -- see Configuration below
    end,
}
```

Requires: Neovim 0.10+, `telescope.nvim`. The plugin must run inside tmux; it
exits early with a warning otherwise.

<details>
<summary>Alternative install methods</summary>

**Shell — without git:**

```bash
curl -fsSL https://raw.githubusercontent.com/OneEyed1366/tmux-projects/main/bin/tmux-sessionizer \
    -o ~/.local/bin/tmux-sessionizer
curl -fsSL https://raw.githubusercontent.com/OneEyed1366/tmux-projects/main/lib/tmux-sessionizer.sh \
    -o ~/.local/lib/tmux-sessionizer.sh
chmod +x ~/.local/bin/tmux-sessionizer
```

**Neovim — with packer.nvim:**

```lua
use {
    "OneEyed1366/tmux-projects",
    config = function() require("tmux-projects").setup({}) end,
}
```

**Neovim — with vim-plug:**

```vim
Plug 'OneEyed1366/tmux-projects'
" then in init.lua:
lua require('tmux-projects').setup({})
```

</details>

---

## See it work

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

`★` is a pinned project from `~/.config/tmux-projects.txt`. `●` is a live
tmux session. The other entries are auto-discovered project roots (any dir
under `~/projects` or `~/personal` containing a `.git`, plus their direct
children).

---

## The problem

You work on a handful of projects. To switch, you `cd`, restart nvim, lose
your LSPs, lose your buffer list, lose your undo history. By the time you've
context-switched three times in an afternoon, half your time is on
rehydration.

A tmux session per project solves this — the session stays alive, the panes
stay alive, nvim stays alive. The friction is naming and remembering the
sessions. fzf + a curated list of projects is the obvious fix.

If you've used [ThePrimeagen's tmux-sessionizer][primeagen], [telescope-project.nvim][telescope-project],
or [Harpoon][harpoon], the shape is familiar. What's new here is the
**symmetry contract**: the bash script and the nvim plugin read the same
pin file, use the same session-naming rule, and produce the same UI markers
(`★`/`●`/`+`). Pin a project from either surface, see it in the other. The
contract is enforced by tests on both sides — divergence is a CI failure.

[primeagen]: https://github.com/ThePrimeagen/tmux-sessionizer
[telescope-project]: https://github.com/nvim-telescope/telescope-project.nvim
[harpoon]: https://github.com/ThePrimeagen/harpoon

---

## Getting started

**Day 1.** Install, run `tmux-sessionizer`, pick a project. Confirm the
session was created (`tmux ls`).

**Day 2.** Pick a project you don't see in the list. Hit `+ Browse for
folder…` and choose a directory. It's now pinned (look for `★` next time).

**Day 3.** Inside nvim, `<leader>p` opens the same picker (or `:TmuxProjects`).
Pick a project — same tmux session, same nvim state.

**Optional.** Add your own scan roots if you keep projects in non-standard
locations. Pin your dotfiles. Pin work stuff separately from personal.

---

## How it works

`tmux-sessionizer` builds a list of four entry types and hands them to fzf
or Telescope: live sessions (`●`), pinned projects (`★`), auto-scanned
project roots, and the "Browse for folder…" entry (`+`). On selection, if
a session with the matching name exists, the script/plugin switches into it;
otherwise it spawns a new session running nvim in the chosen directory.

<details>
<summary>Architecture — data flow</summary>

```
              ┌─────────────────────────────────────────────┐
              │           ~/.config/tmux-projects.txt      │
              │     # one absolute path per line (# = com) │
              └────────────┬────────────────────────────────┘
                           │  read
            ┌──────────────┴──────────────┐
            ▼                             ▼
   ┌────────────────┐            ┌─────────────────┐
   │  bin/tmux-     │            │  nvim-plugin/   │
   │  sessionizer   │            │  lua/tmux-      │
   │  (bash + fzf)  │            │  projects/      │
   │                │            │  (Telescope)    │
   └───────┬────────┘            └────────┬────────┘
           │  env vars (TMUX_*)          │  setup{} opts
           ▼                             ▼
       ┌─────────────────────────────────────┐
       │  fzf popup / Telescope picker UI    │
       │  ★ pinned · ● live · + browse       │
       └────────────────┬────────────────────┘
                        │  selected
                        ▼
              ┌──────────────────────┐
              │  tmux has-session?   │
              │  ├─ yes → switch     │
              │  └─ no  → new + nvim │
              └──────────────────────┘
```

The pin file, session-name rule, and marker vocabulary are the contract.
Both surfaces parse the same file format; both apply the same name
transformation (`path_to_session_name`). Tests in `tests/` enforce this.

</details>

<details>
<summary>Session naming</summary>

A path like `/Users/me/my project` becomes the session name `my_project`.
The rule: take the basename, drop a leading dot (`~/.config` →
`config`), replace ` `, `.`, `:`, `/` with `_`. This keeps tmux's
`session.window.pane` target syntax unambiguous.

The bash and lua implementations must produce identical output for the
same input. The bash tests live in `tests/bash/`, the lua tests in
`tests/lua/`, and they cover the same logical cases.

</details>

---

## Configuration

| What | bash (env var) | nvim (`setup{}` key) | Default |
|---|---|---|---|
| Project roots | `TMUX_SESSIONIZER_ROOTS` (colon-separated) | `roots` (table) | `~/projects:~/personal` |
| Pins file | `TMUX_SESSIONIZER_EXTRA_FILE` | `extra_file` | `~/.config/tmux-projects.txt` |
| Browse label | `TMUX_SESSIONIZER_BROWSE_LABEL` | `browse_label` | `+ Browse for folder…` |
| fzf prompt | `TMUX_SESSIONIZER_PROMPT` | — (Telescope) | `project> ` |
| Max scan depth | `TMUX_SESSIONIZER_MAX_DEPTH` | `max_depth` | `5` |

The pin file format and full session-naming spec live in
[`share/SPEC.md`](share/SPEC.md).

Example — single-user with non-standard roots:

```bash
export TMUX_SESSIONIZER_ROOTS="$HOME/Code:$HOME/work"
```

```lua
require("tmux-projects").setup({
    roots     = { "/Users/me/Code", "/Users/me/work" },
    max_depth = 6,
})
```

---

## Reference

### CLI

| Command | Effect |
|---|---|
| `tmux-sessionizer` | Open fzf picker, switch to / create session |
| `tmux-sessionizer --version` | Print version |
| `tmux-sessionizer --help` | Full help text |
| `tmux-sessionizer --validate` | Smoke-check deps + config; exit 0 if OK |

### Neovim commands

| Command | Effect |
|---|---|
| `:TmuxProjects` | Open the picker (alias for `<leader>p` if you bind it) |
| `:TmuxKill` | Multi-select kill picker for tmux sessions |
| `require("tmux-projects").open()` | Same as `:TmuxProjects` |
| `require("tmux-projects").kill()` | Same as `:TmuxKill` |

Suggested which-key bindings (in your config):

```lua
{ "<leader>p",  function() require("tmux-projects").open() end, desc = "Switch project" },
{ "<leader>kp", function() require("tmux-projects").kill() end, desc = "Kill project sessions" },
```

---

## FAQ

**Why a monorepo, not two repos?**
The bash and lua sides share a contract (pin file format, session naming,
markers). One repo, one version, one PR. If the contract needs to break,
it breaks in both places at once.

**Why a separate bin and lua plugin, not one Lua thing?**
fzf-in-a-tmux-popup is the right surface when you're already in the
shell. Telescope is the right surface when you're already in nvim. Same
state, two presentations. No "Telescope-only" users lose the fzf; no
"fzf-only" users lose the picker.

**Why no automatic pinning on first switch?**
Pinned projects are intentional — they're the curated short list, not
"every project I've ever opened." Auto-pinning everything makes the
pinned list useless. Browse-and-pin is the explicit gesture.

**Does this work with Ghostty / iTerm / Alacritty / Windows Terminal?**
Yes — the bash side is a shell script that calls `tmux` and the system
folder picker. Any terminal that can run `tmux` works. The native
folder picker auto-detects osascript (macOS) → zenity (GNOME) →
kdialog (KDE) → PowerShell (WSL/Windows).

**How is this different from ThePrimeagen's tmux-sessionizer?**
The shell UX is similar (fzf picker, live sessions, scanned roots,
extra file). The differences: (a) the extra file is the contract, not
an internal detail — the lua plugin reads the same file; (b) the bash
and lua implementations of the session-naming rule are tested against
each other; (c) everything is env-configurable, no hardcoded paths.

---

## Contributing

Issues and PRs welcome. Before opening a PR:

```bash
make lint     # shellcheck + stylua
make test     # bats + mini.test
```

If you're changing the pin file format or session-naming rule, please
update `share/SPEC.md` and the tests in both `tests/bash/` and
`tests/lua/`. The contract is the point.

## License

MIT — see [LICENSE](LICENSE).
