## What

<!-- One-line summary of the change -->

## Why

<!-- Why is this change needed? What does it enable or fix? -->

## How

<!-- Brief description of the implementation -->

## Contract

The bash script (`bin/`) and the nvim plugin (`nvim-plugin/`) share a
contract: same pin file format, same `path_to_session_name` rule, same
picker markers.

- [ ] This PR does NOT change the contract
- [ ] This PR changes the contract — `share/SPEC.md` is updated AND
      tests on both sides are added/updated

## Testing

- [ ] `make lint` passes (shellcheck + stylua)
- [ ] `make test` passes (34 bats + 28 mini.test = 62 tests)
- [ ] New tests cover the change (if behavior is added or contract changed)
- [ ] Local install + manual smoke check: `<describe what you tried>`

## Checklist

- [ ] Branch is off `master` (not off a personal branch)
- [ ] Commit messages follow Conventional Commits
- [ ] No `as any` or unsafe casts in lua
- [ ] No `--no-verify` (hooks pass on their own)
- [ ] No `.js` / `node_modules` / `lazy-lock.json` (build artifacts)

## Notes for reviewers

<!-- Anything reviewers should pay attention to: areas of risk, design
decisions, alternative approaches considered, etc. -->
