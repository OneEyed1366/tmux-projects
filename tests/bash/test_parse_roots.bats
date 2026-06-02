#!/usr/bin/env bats
#
# Unit tests for parse_roots (lib/tmux-sessionizer.sh).
# Verifies colon-separated parsing and tilde expansion.

setup() {
    LIB="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/lib/tmux-sessionizer.sh"
    source "$LIB"
}

@test "parse_roots: empty input leaves ROOTS empty" {
    parse_roots ""
    [ "${#ROOTS[@]}" -eq 0 ]
}

@test "parse_roots: single entry unchanged" {
    parse_roots "/foo/bar"
    [ "${#ROOTS[@]}" -eq 1 ]
    [ "${ROOTS[0]}" = "/foo/bar" ]
}

@test "parse_roots: colon-separated splits into array" {
    parse_roots "/foo:/bar:/baz"
    [ "${#ROOTS[@]}" -eq 3 ]
    [ "${ROOTS[0]}" = "/foo" ]
    [ "${ROOTS[1]}" = "/bar" ]
    [ "${ROOTS[2]}" = "/baz" ]
}

@test "parse_roots: ~ expands to HOME" {
    parse_roots "~"
    [ "${ROOTS[0]}" = "$HOME" ]
}

@test "parse_roots: ~/ expands to HOME/" {
    parse_roots "~/projects"
    [ "${ROOTS[0]}" = "$HOME/projects" ]
}

@test "parse_roots: mixed tilde and absolute" {
    parse_roots "/abs:~/tilde:~/foo"
    [ "${ROOTS[0]}" = "/abs" ]
    [ "${ROOTS[1]}" = "$HOME/tilde" ]
    [ "${ROOTS[2]}" = "$HOME/foo" ]
}

@test "parse_roots: empty entries are preserved" {
    parse_roots "/foo::/bar"
    [ "${#ROOTS[@]}" -eq 3 ]
    [ "${ROOTS[1]}" = "" ]
}

@test "parse_roots: HOME is global, not captured" {
    parse_roots "~/x"
    # The function should NOT overwrite HOME
    [ "$HOME" != "" ]
    [ "${ROOTS[0]}" = "$HOME/x" ]
}
