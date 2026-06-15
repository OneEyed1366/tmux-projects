---
name: release
description: Cut a new release of tmux-projects — bump the version, close the changelog, tag, and push so the GitHub release workflow fires. Use whenever the user asks to "сделать релиз", "cut a release", "ship a version", "bump the version", or notes that a release is missing on GitHub after a push.
---

# Release

This repo (`tmux-projects`) releases by hand-editing two files, committing a
release commit in Conventional Commits style, tagging, and pushing. A GitHub
Actions workflow (`.github/workflows/release.yml`) listens for `v*` tags and
creates the GitHub release with auto-generated notes. There is no release
script — the steps below *are* the process.

## What a release touches

- `bin/tmux-sessionizer` — the `VERSION="x.y.z"` line near the top (~line 9).
- `CHANGELOG.md` — keepachangelog format. Each release is a `## [x.y.z] - YYYY-MM-DD`
  section. The repo does **not** keep a standing `[Unreleased]` section, so a
  release adds a fresh dated section at the top of the list, above the previous
  release.

## Steps

1. **Read the state.** `git status`, `git log --oneline -10`, `git tag`. Confirm
   the working tree is clean (the feature/fix commits you're releasing are
   already committed) and find the current version.

2. **Pick the version.** Follow semver against the commits since the last tag:
   - `feat:` → minor bump (e.g. 0.2.1 → 0.3.0)
   - `fix:` / `refactor:` / `chore:` only → patch bump
   - breaking change → major bump
   Inspect the commit subjects rather than guessing.

3. **Bump `VERSION`** in `bin/tmux-sessionizer`.

4. **Add the CHANGELOG section.** Insert a new `## [x.y.z] - YYYY-MM-DD` block
   above the previous release's section. Use today's date (`date +%Y-%m-%d`).
   Group entries under `### Added` / `### Changed` / `### Fixed` / `### Notes` as
   appropriate, written from the user's perspective (what changed for them), not
   as a raw commit dump. Match the prose style of existing entries.

5. **Commit** with subject `chore(release): x.y.z` (this exact format — see prior
   release commits). Stage both files.

6. **Tag — annotated, not lightweight.** This is the step that bites:
   ```
   git tag -a vx.y.z -m "vx.y.z"
   ```
   A lightweight tag (`git tag vx.y.z`) will NOT be pushed by
   `git push --follow-tags`, so the release workflow never fires and no GitHub
   release appears. Always create an **annotated** tag.

7. **Push.** `git push origin master --follow-tags`. Then verify the tag actually
   reached the remote:
   ```
   git ls-remote --tags origin | grep vx.y.z
   ```
   If it's missing (e.g. the tag was lightweight), push it explicitly:
   `git push origin vx.y.z`.

8. **Confirm the release.** Give the workflow a few seconds, then:
   ```
   gh run list --limit 3       # expect a fresh `release` run
   gh release list --limit 3   # expect vx.y.z marked Latest
   ```
   If `gh run list` shows only a `ci` run and no `release`, the tag didn't reach
   origin — go back to step 7.

## Why annotated tags matter here

`--follow-tags` deliberately only pushes annotated, signed tags — it skips
lightweight ones to avoid pushing throwaway local markers. The release workflow
triggers on `push: tags: ['v*']`, so a tag that never leaves the laptop means a
version that exists locally but has no GitHub release. Creating the tag annotated
from the start avoids the "а релиза нет" surprise and the manual re-push.
