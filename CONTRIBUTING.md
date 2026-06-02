# Contributing

Issues and PRs welcome. Please read this first.

## Local setup

```bash
git clone https://github.com/OneEyed1366/tmux-projects.git
cd tmux-projects
```

Install dev tools on macOS:

```bash
brew install shellcheck stylua bats-core
```

On Debian/Ubuntu:

```bash
sudo apt install shellcheck bats
# stylua: download from https://github.com/JohnnyMorganz/StyLua/releases
sudo curl -L -o /usr/local/bin/stylua \
    https://github.com/JohnnyMorganz/StyLua/releases/latest/download/stylua-linux-x86_64.zip
```

The `nvim` binary itself is only needed if you're modifying the lua side.

## Workflow

1. **Branch off `master`.** `git checkout -b fix/your-thing`
2. **Make focused commits.** One logical change per commit. Prefer
   squash-merge style for the final PR — individual commits in the
   PR don't need to be polished.
3. **Test before pushing.** `make test && make lint`
4. **Open a PR.** Target `master`. Fill in the PR template.
5. **CI must be green.** Four jobs: shellcheck, stylua, bats, mini.test.

## The contract

The bash script (`bin/tmux-sessionizer`) and the nvim plugin
(`nvim-plugin/lua/tmux-projects/`) MUST agree on:

- **Pin file format** — one path per line, `#` comments, blank lines
  ignored, trailing slash stripped. Full spec in `share/SPEC.md`.
- **Session naming** — basename, leading dot dropped, ` ` `.` `:` `/`
  replaced with `_`. Full spec in `share/SPEC.md`.
- **Picker markers** — `★` pinned, `●` live, `+ Browse for folder…`
  (configurable via `browse_label`).

If you change the contract, update `share/SPEC.md` AND add tests on
BOTH sides (bash and lua). The CI runs both — divergence is a
failure, not a surprise.

The symmetry contract is enforced by:

- `tests/bash/test_path_to_session_name.bats`
- `tests/lua/path_to_session_name_spec.lua`

Both files test the same logical cases. If you add a case to one,
add it to the other.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/). One line,
< 72 chars:

```
feat: add keyword search in pin file
fix(bash): handle CRLF in pin file
docs: clarify symlink behavior in install.sh
refactor(nvim): extract entries builder
test: add idempotency edge case for read_pins
chore: bump dependencies
```

## Release flow

1. Bump version in `bin/tmux-sessionizer` (`VERSION="X.Y.Z"`)
2. Add a section to `CHANGELOG.md`
3. Commit on `master`: `chore: release vX.Y.Z`
4. `git tag vX.Y.Z && git push origin vX.Y.Z`
5. `.github/workflows/release.yml` creates a GitHub release with
   auto-generated notes

## Communication

- **Bugs and features** → GitHub Issues
- **Questions and ideas** → GitHub Discussions
- **Security issues** → see [`SECURITY.md`](SECURITY.md)
