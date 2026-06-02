# tmux-projects

A project switcher that fuses tmux, fzf, and Neovim into one workflow.

- **`bin/tmux-sessionizer`** — bash + fzf popup, runs from the shell
- **`nvim-plugin/`** — Neovim plugin with a native Telescope picker (`tmux-projects.nvim`)

Both share the same pin file (`~/.config/tmux-projects.txt`) and the same
session-naming rules. Pin a project once → see it as `★` in both UIs.

## Install

(coming soon)

## Configuration

| What | bash (env var) | nvim (`setup{}`) | Default |
|------|----------------|------------------|---------|
| Project roots | `TMUX_SESSIONIZER_ROOTS` (colon-separated) | `roots` (table) | `~/projects:~/personal` |
| Pins file | `TMUX_SESSIONIZER_EXTRA_FILE` | `extra_file` | `~/.config/tmux-projects.txt` |
| Browse label | `TMUX_SESSIONIZER_BROWSE_LABEL` | `browse_label` | `+ Browse for folder…` |
| fzf prompt | `TMUX_SESSIONIZER_PROMPT` | — (Telescope) | `project> ` |
| Max scan depth | `TMUX_SESSIONIZER_MAX_DEPTH` | `max_depth` | `5` |

See [`share/SPEC.md`](share/SPEC.md) for the pin file format and session
naming rules.

## License

MIT — see [LICENSE](LICENSE).
