# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.2] - 2026-06-16

### Fixed

- Neovim plugin installs and updates now consistently run `install.sh`.
  The repo ships a `build.lua` hook for `lazy.nvim`, and the README
  examples for `lazy.nvim`, `packer.nvim`, and `vim-plug` now wire the
  same post-install step explicitly.

## [0.3.1] - 2026-06-04

### Fixed

- Opening a project no longer hangs when invoked from a context that
  isn't a real tmux client — most visibly `lazygit` worktree switching
  inside nvim. Previously `$TMUX` could be unset for such grandchild
  processes, so the script fell back to `tmux attach`, which blocks
  forever without a tty client. It now also treats `$TMUX_SOCKET` as
  "inside tmux" and uses `switch-client` in these cases.

## [0.3.0] - 2026-06-04

### Added

- `tmux-sessionizer open <path>` — non-interactive entry point that
  runs the same reuse-or-create-then-switch flow for an explicit path,
  skipping the fzf picker. Intended for scripts and editor integrations
  (e.g. lazygit worktree switching).
- `tmux-sessionizer kill <path>` — kills the session bound to `<path>`
  if it exists, idempotent no-op otherwise. Intended for cleanup when a
  worktree/project is removed.

## [0.2.1] - 2026-06-03

### Fixed

- Pin file `unpin` / `pins.remove` now preserve the file's exact
  byte sequence, including the trailing-newline state. A file
  without a final `\n` stays without one; a file with one keeps
  one. Previously the lua `pins.remove` would drop the last line
  on unterminated files, and the bash `unpin` would silently
  append a `\n` if the original lacked one.

### Changed

- `BROWSE_LABEL` default dropped the `(Finder)` suffix in help
  text, default value, and fzf header. Picker is cross-platform
  (osascript / zenity / kdialog / powershell); the macOS-only
  suffix was misleading on Linux/WSL.

## [0.2.0] - 2026-06-02

### Added

- `d` / `<C-d>` key in the Telescope picker removes a project
  from the pin file (also kills the live tmux session, with a
  confirmation prompt). `d` in normal mode (vim muscle memory
  for the `dd` line-delete command), `<C-d>` in insert mode (bare
  letters would type into the filter prompt). Both bound on
  both the prompt and results buffers — works regardless of
  which window has focus.
- `<C-r>` / `r` key in the Telescope picker renames the current
  entry's tmux session. `r` in normal mode (vim muscle memory),
  `<C-r>` in insert mode (bare letters type into the filter
  prompt). Bound on both the prompt and results buffers. Pinned
  rows that have a live session can also be renamed — the
  derived session name is used as the "old" name.
- `tmux-sessionizer unpin <path>` CLI subcommand — idempotent, line-
  preserving, works outside tmux too
- `lib/tmux-sessionizer.sh::unpin()` — atomic, idempotent, preserves
  `#` comments and blank lines in the pin file
- `lua/tmux-projects.pins.remove()` — Lua mirror of the bash `unpin`,
  same line-preserving and atomic-via-temp+rename semantics

### Changed

- Picker `<C-d>` on a `● <name>` (live-only) row now confirms and
  kills the session, instead of refusing with a hint to use
  `:TmuxKill`. The single-row quick path lives on the picker; bulk
  multi-select kill still uses `:TmuxKill`.
- After every successful `<C-d>` or `<C-r>` action, the picker
  refreshes in place via `Picker:refresh(finder, { reset_prompt = false })`.
  The user stays in the picker with their filter text preserved —
  no close-and-reopen dance.

### Notes

- **Deletion is unpinnning, not file removal.** The `d` / `<C-d>`
  action (and the `unpin` subcommand) remove the path from
  `~/.config/tmux-projects.txt` only. The project directory on
  disk is **never touched**. To restore a project, browse for it
  or add the path manually to the pin file.
- **Renaming affects the tmux session, not the pin file.** The
  pin file is a list of paths, not names. After a rename, the
  picker shows both `● <new>` and `★ /path` for the same project;
  unpin and re-browse to clean up the display if you care.
- Picker now shows `(Enter=open  d=delete  r=rename)` in the
  prompt title.

## [0.1.0] - 2026-06-02

### Added

- `bin/tmux-sessionizer` — bash + fzf popup project switcher
- `lua/tmux-projects/` + `plugin/` — Neovim plugin with Telescope picker (`tmux-projects.nvim`)
- Shared pin file format (`~/.config/tmux-projects.txt`) — one path per line,
  `#` comments, blank lines ignored, trailing slash stripped
- Symmetry contract between bash and lua: same pin file, same
  `path_to_session_name` rule, same picker markers (`★`/`●`/`+`)
- CLI flags: `--help`, `--version`, `--validate` (and short forms)
- Bash env vars: `TMUX_SESSIONIZER_ROOTS`, `TMUX_SESSIONIZER_EXTRA_FILE`,
  `TMUX_SESSIONIZER_BROWSE_LABEL`, `TMUX_SESSIONIZER_PROMPT`,
  `TMUX_SESSIONIZER_MAX_DEPTH`
- Nvim `setup{}` keys: `roots`, `extra_file`, `browse_label`, `max_depth`
- Native OS folder picker integration: `osascript` (macOS) → `zenity` (GNOME)
  → `kdialog` (KDE) → `powershell.exe` (WSL/Windows)
- `install.sh` and `uninstall.sh` (standalone, no `make` required)
- `Makefile` with `install`/`uninstall`/`test`/`test-bash`/`test-lua`/
  `lint`/`lint-bash`/`lint-lua`/`clean`/`help` targets
- Tests: 34 bats cases + 28 mini.test cases (62 total) covering the
  symmetry contract end-to-end
- CI: 4 parallel GitHub Actions jobs (shellcheck, stylua, bats, mini.test)
- Release workflow: tag push → GitHub release with auto-generated notes
- `act`-compatible workflow files (tested locally with `catthehacker/ubuntu:act-latest`)
- Comprehensive README with install matrix, configuration, and mappings
- Pin file spec: [`share/SPEC.md`](share/SPEC.md)

### Notes

- License: MIT
- Default project roots: `~/projects:~/personal`
- Default pin file: `~/.config/tmux-projects.txt`
- Minimum requirements: bash 4+, tmux 3+, fzf, fd, Neovim 0.10+ (plugin)
