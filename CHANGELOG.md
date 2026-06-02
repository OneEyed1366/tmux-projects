# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-02

### Added

- `bin/tmux-sessionizer` — bash + fzf popup project switcher
- `nvim-plugin/` — Neovim plugin with Telescope picker (`tmux-projects.nvim`)
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
- 1532-word gold-standard README + 553-word nvim-plugin README
- Pin file spec: [`share/SPEC.md`](share/SPEC.md)

### Notes

- License: MIT
- Default project roots: `~/projects:~/personal`
- Default pin file: `~/.config/tmux-projects.txt`
- Minimum requirements: bash 4+, tmux 3+, fzf, fd, Neovim 0.10+ (plugin)
