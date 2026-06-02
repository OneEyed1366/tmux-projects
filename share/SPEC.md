# Pin file format

Path: `~/.config/tmux-projects.txt` by default.
Override via `TMUX_SESSIONIZER_EXTRA_FILE` (bash) or `setup({ extra_file = "..." })` (nvim).

## Rules

- One absolute path per line
- Lines starting with `#` are comments (whitespace before `#` is OK)
- Blank lines are ignored
- Trailing slashes are stripped
- Whitespace at line ends is stripped
- Deduplication is exact-match (case-sensitive, no normalization)

## Picker UI markers

| Marker | Meaning |
|--------|---------|
| `●` | Live tmux session |
| `★` | Pinned project (from this file) |
| `  ` (no marker) | Auto-scanned project (git root or top-level dir under `ROOTS`) |
| `+ Browse for folder…` | Opens the native OS folder picker; auto-pins the chosen path |

## Session naming

`path_to_session_name` is the shared rule between bash and lua. Both
implementations must produce identical names for the same input.

1. Take the **basename** of the path
2. Drop a **leading dot** (`~/.config` → `config`, not `_config`)
3. Replace ` `, `.`, `:`, `/` with `_` so tmux's `session.window.pane`
   target syntax doesn't get confused

| Input | Output |
|-------|--------|
| `~/.config` | `config` |
| `~/my project` | `my_project` |
| `/var/log` | `log` |
| `~/a.b/c.d` | `c.d` (only basename is transformed) |
| `~/work//foo` | `foo` (intermediate slashes don't matter; basename is the result) |

## Symmetry contract

The bash script (`bin/tmux-sessionizer`) and the nvim plugin
(`lua/tmux-projects/`) MUST:

- Read the same file at the same path
- Apply identical `path_to_session_name` rules
- Use the same `ROOTS` list (via different config mechanisms)
- Dedup pinned entries against live sessions identically

Tests in `tests/` enforce this. Both `tests/bash/` and `tests/lua/` cover
the same logical cases.
