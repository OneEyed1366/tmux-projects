#!/usr/bin/env bats
#
# Smoke tests for the CLI flags of bin/tmux-sessionizer.
# Verifies that --help, --version, --validate behave as documented.

setup() {
    BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/bin/tmux-sessionizer"
}

@test "--version prints the version" {
    run "$BIN" --version
    [ "$status" -eq 0 ]
    [[ "$output" == "tmux-sessionizer "* ]]
}

@test "-v is alias for --version" {
    run "$BIN" -v
    [ "$status" -eq 0 ]
    [[ "$output" == "tmux-sessionizer "* ]]
}

@test "--help prints USAGE block" {
    run "$BIN" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE:"* ]]
    [[ "$output" == *"TMUX_SESSIONIZER_ROOTS"* ]]
    [[ "$output" == *"TMUX_SESSIONIZER_EXTRA_FILE"* ]]
}

@test "-h is alias for --help" {
    run "$BIN" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE:"* ]]
}

@test "--validate: passes when tmux/fzf/fd exist and ROOTS are real" {
    # Override ROOTS to /tmp so the test doesn't depend on ~/projects or
    # ~/personal existing in the test env (CI runners don't have them).
    TMUX_SESSIONIZER_ROOTS=/tmp run "$BIN" --validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK tmux="* ]]
    [[ "$output" == *"OK roots="* ]]
    [[ "$output" == *"OK extra_file="* ]]
}

# почему: NEGATIVE — silent success on misconfigured roots is a
# usability bug. The user sets `TMUX_SESSIONIZER_ROOTS=~/Code` and
# forgets to mkdir `~/Code`; the first fzf run then renders an
# empty picker and the user thinks the script is broken. Exit 1 +
# explicit warning is the contract.
@test "--validate: fails when ROOTS env points only to nonexistent dirs" {
    TMUX_SESSIONIZER_ROOTS=/nonexistent1:/nonexistent2 run "$BIN" --validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"Warning: none of the configured ROOTS exist"* ]]
}

# почему: NEGATIVE for the wrong-target-detection, POSITIVE for
# the env-pass-through. --validate is a smoke test for ops/CI; if
# it doesn't reflect env overrides, the user can't trust it.
@test "--validate: reflects TMUX_SESSIONIZER_EXTRA_FILE" {
    # Override ROOTS so the test doesn't depend on user dirs existing.
    TMUX_SESSIONIZER_ROOTS=/tmp \
    TMUX_SESSIONIZER_EXTRA_FILE=/tmp/extra-test.txt \
    run "$BIN" --validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK extra_file=/tmp/extra-test.txt"* ]]
    rm -f /tmp/extra-test.txt
}

@test "unknown option exits non-zero with hint" {
    run "$BIN" --bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown option"* ]]
    [[ "$output" == *"--help"* ]]
}
