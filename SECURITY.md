# Security

## Reporting a vulnerability

Please **do not** file public GitHub issues for security problems.

Email the maintainer: **psevdoproger@gmail.com**

Include:

- Description of the issue
- Steps to reproduce
- Affected version (commit hash or tag)
- Potential impact

You'll get a response within 72 hours.

## Scope

In scope:

- The bash script (`bin/tmux-sessionizer`) and the install/uninstall
  scripts — both are network-capable if extended in the future
- The nvim plugin — runs in your editor, has full Lua access

Out of scope:

- Misconfigured user environments (the script respects env vars; if
  you point `TMUX_SESSIONIZER_ROOTS` at a sensitive directory, that's
  on you)

## Trust model

The project does NOT:

- Make network calls
- Run telemetry or analytics
- Modify your nvim config, your tmux config, or your shell rc
- Write inside the projects you switch into

The project DOES:

- Spawn `tmux new-session` and run `nvim` (or whatever shell command
  the user has set) in a new tmux session
- Create `~/.config/tmux-projects.txt` on first use of "Browse for
  folder…" (append-only)

For full trust info, see the trust block at the top of `README.md`.
