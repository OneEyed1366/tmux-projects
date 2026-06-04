# AGENTS.md

## What this is

A two-sided project switcher that fuses `tmux`, `fzf`, and Neovim:

- Bash side: `bin/tmux-sessionizer` (CLI), `lib/tmux-sessionizer.sh` (pure functions, sourced by the script and the bats tests).
- Neovim side: `lua/tmux-projects/` modules loaded via `plugin/tmux-projects.lua`.

The two sides share a pin file (`~/.config/tmux-projects.txt`) and a session-naming rule. Diverging on either is a CI failure — see [Symmetry contract](#symmetry-contract) below.

## Layout

| Path | Role |
|---|---|
| `bin/tmux-sessionizer` | Executable CLI. Sources `lib/`, then implements flags, fzf invocation, and `tmux new-session`. Holds `VERSION=`. |
| `lib/tmux-sessionizer.sh` | Pure functions: `path_to_session_name`, `parse_roots`, `read_pins`, `add_pin`, `unpin`. Sourced, not executed — no top-level side effects. |
| `lua/tmux-projects/` | Neovim plugin: `init.lua` (entry), `config.lua`, `pins.lua`, `scan.lua`, `tmux.lua`, `pickers/{open,kill,native}.lua`. |
| `plugin/tmux-projects.lua` | Tiny nvim loader that requires `tmux-projects.setup`. |
| `share/SPEC.md` | **Authoritative** contract: pin file format, session-naming rule, picker markers (`★` `●` `+`). |
| `tests/bash/*.bats` | bats-core unit tests. Each `setup()` sources the lib. |
| `tests/lua/*_spec.lua` | mini.test specs. Run via `tests/lua/minimal_init.lua`. |
| `install.sh`, `Makefile`, `uninstall.sh` | Install / uninstall. PREFIX defaults to `~/.local`. |
| `.docs/` | Local knowledge base. **Gitignored** — never commit. |

## Symmetry contract (the most important rule)

`bin/tmux-sessionizer` and `lua/tmux-projects/` MUST agree on:

- Pin file format (one absolute path per line, `#` comments OK, blanks ignored, trailing slashes stripped).
- `path_to_session_name` rule: basename → drop leading dot → replace ` ` `.` `:` `/` with `_`.
- Picker markers: `★` pinned, `●` live, `+ Browse for folder…` (configurable), `  ` scanned.
- `ROOTS` semantics (config mechanisms differ, contents must match).

If you change a contract rule, update **both** implementations **and** add the test case to both `tests/bash/test_path_to_session_name.bats` and `tests/lua/path_to_session_name_spec.lua`. The contract spec lives in `share/SPEC.md` — keep it in sync.

A subtle asymmetry to remember when porting: bash `basename` strips trailing slashes; `vim.fn.fnamemodify(p, ":t")` returns `""` for a path ending in `/`. `lua/tmux-projects/tmux.lua::path_to_session_name` strips trailing slashes explicitly to match bash. Don't "simplify" that.

## Commands

All commands run from the repo root.

```bash
make test                # bats + mini.test
make test-bash           # bats tests/bash/*.bats
make test-lua            # nvim --headless + mini.test
make lint                # shellcheck + stylua
make lint-bash           # shellcheck bin/, lib/, install.sh, uninstall.sh
make lint-lua            # stylua --check lua/
make install             # copies to $PREFIX/bin and $PREFIX/lib (default ~/.local)
make uninstall
```

Single-test shortcuts:

```bash
bats tests/bash/test_path_to_session_name.bats           # one bats file
bats tests/bash/test_pins_file.bats --filter 'idempotent'  # one @test
nvim --headless -u tests/lua/minimal_init.lua \
  -c "lua MiniTest.run_file('tests/lua/pins_spec.lua')" -c "qa!"
```

`tmux-sessionizer --validate` is a post-install smoke check (deps + config) — useful for users, not for CI.

## Tooling notes (CI and local)

- `bats` on Homebrew is `bats-core` (`brew install bats-core`). `make test-bash` fails loudly if missing.
- `stylua` is not in apt; CI downloads the linux x86_64 zip. `brew install stylua` on macOS.
- `fd` on Debian/Ubuntu ships as `fdfind`; CI symlinks `/usr/local/bin/fd → fdfind`. Locally just install `fd`.
- CI nvim version is **pinned to v0.10.2** (not the `stable` tag, which 302-redirects and broke a previous CI run). Don't bump casually.
- `tests/lua/minimal_init.lua` auto-clones `mini.nvim`, `plenary.nvim`, `telescope.nvim` into `~/.local/share/nvim/lazy/` on first run if missing.

## Lint discipline

- `shellcheck` runs on the four bash files. `lib/tmux-sessionizer.sh` carries explicit `disable=SC2001` and `disable=SC2088` near the relevant lines — keep them if the rationale still holds; otherwise re-enable.
- `stylua` config (`.stylua.toml`): spaces, 4-wide indent, 120-col width, Unix line endings. CI runs `--check` only.
- Both `make lint` jobs are part of CI. They must pass before merge.

## Workflow

- Branch off `master`. One logical change per commit. Squash-merge is fine for the PR.
- Conventional Commits, one line, <72 chars. Examples live in `CONTRIBUTING.md`. CI does not enforce format — humans do at review.
- Before push: `make test && make lint`.
- PR target: `master`. CI runs on `push` to `master` and `feature/**`, and on `pull_request` to `master`.
- Release flow: bump `VERSION="X.Y.Z"` in `bin/tmux-sessionizer`, add a section to `CHANGELOG.md`, commit on `master` as `chore: release vX.Y.Z`, tag `vX.Y.Z`. `release.yml` creates the GitHub release on tag push.

## Gotchas worth knowing

- The Neovim plugin must run **inside a tmux session** (it queries `vim.env.TMUX` for the socket). Running `:TmuxProjects` outside tmux exits with a warning.
- The bash script always passes `-L <socket>` to `tmux` so it talks to the right per-window server (Ghostty-tmux, multi-server setups). Socket comes from `$TMUX_SOCKET` or is parsed out of `$TMUX`. The lua side does the same in `lua/tmux-projects/tmux.lua::cmd`.
- `parse_roots` and `read_pins` set **global arrays** (`ROOTS`, `PINS`) by design — they're called from the sourced lib where subshells would lose the values. Don't refactor them to `echo`/stdout without also updating every caller.
- `unpin` (bash) and `pins.remove` (lua) are **atomic via temp + rename** and **line-preserving**: `#` comments, blank lines, and ordering of surviving entries survive untouched. The pin file is the user's curated list — silently dropping annotations is data loss. See `pins.lua::remove` docstring for the rationale.
- `config.lua` uses `vim.tbl_deep_extend("force", defaults, user)`, whose behavior on `roots` (a list value) is **non-obvious and version-dependent** — recent Neovim concatenates the two lists, but older versions and nested-table positions silently drop the defaults. The README documents `roots` as a sequence replaced wholesale and shows a `vim.list_extend` workaround. Use the `vim.list_extend` pattern when you need a specific list; don't rely on the merge to do what you want.
- `share/tmux-projects.txt.example` is a sample pin file, not a real config; do not read it at runtime.
- `.docs/` is gitignored (see `.gitignore`) and is the local knowledge base for this project. Don't add it to the repo.

## Where to look first

- Architecture / contract question → `share/SPEC.md` then `bin/tmux-sessionizer` + `lua/tmux-projects/init.lua` (the two top-level entry points).
- Behavior question about a key (`d`, `<C-d>`, `r`, `<C-r>`) → `lua/tmux-projects/pickers/open.lua` and the README "Default mappings" table.
- Pin-file question → `lib/tmux-sessionizer.sh` (bash) and `lua/tmux-projects/pins.lua` (lua), plus the parallel bats/mini.test specs.
- Session-name question → both `path_to_session_name` implementations and their mirrored spec files.
- Release question → `CONTRIBUTING.md` "Release flow" section, plus `bin/tmux-sessionizer::VERSION` and `CHANGELOG.md`.
