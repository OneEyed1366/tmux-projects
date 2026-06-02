#!/usr/bin/env bats
#
# Unit tests for read_pins and add_pin (lib/tmux-sessionizer.sh).
# Covers pin file parsing, dedup, and idempotent add.

setup() {
    LIB="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/lib/tmux-sessionizer.sh"
    source "$LIB"
    TEST_PIN_FILE="$(mktemp)"
    export TEST_PIN_FILE
}

teardown() {
    rm -f "$TEST_PIN_FILE"
}

@test "read_pins: missing file → PINS empty" {
    rm -f "$TEST_PIN_FILE"
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 0 ]
}

@test "read_pins: simple one-path file" {
    printf '/Users/me/projects/foo\n' > "$TEST_PIN_FILE"
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 1 ]
    [ "${PINS[0]}" = "/Users/me/projects/foo" ]
}

@test "read_pins: ignores # comment lines" {
    cat > "$TEST_PIN_FILE" <<EOF
# This is a comment
/Users/me/projects/foo
# /Users/me/commented/out
/Users/me/personal/bar
EOF
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 2 ]
    [ "${PINS[0]}" = "/Users/me/projects/foo" ]
    [ "${PINS[1]}" = "/Users/me/personal/bar" ]
}

@test "read_pins: ignores blank lines" {
    cat > "$TEST_PIN_FILE" <<EOF
/Users/me/projects/foo

/Users/me/personal/bar

EOF
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 2 ]
}

@test "read_pins: strips trailing slashes" {
    printf '/Users/me/projects/foo/\n' > "$TEST_PIN_FILE"
    read_pins "$TEST_PIN_FILE"
    [ "${PINS[0]}" = "/Users/me/projects/foo" ]
}

@test "read_pins: indented comment is still a comment" {
    cat > "$TEST_PIN_FILE" <<EOF
   # leading-whitespace comment
/Users/me/foo
EOF
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 1 ]
    [ "${PINS[0]}" = "/Users/me/foo" ]
}

@test "add_pin: appends new path" {
    add_pin "$TEST_PIN_FILE" "/Users/me/new"
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 1 ]
    [ "${PINS[0]}" = "/Users/me/new" ]
}

# почему: DEDUP IS THE CONTRACT. If a pinned path appears twice in
# the file, the picker renders BOTH `★ /foo` and `★ /foo` markers for
# the same project, and the user sees duplicate entries. This is the
# most-user-visible regression risk of add_pin.
@test "add_pin: idempotent — second add of same path is no-op" {
    add_pin "$TEST_PIN_FILE" "/Users/me/foo"
    add_pin "$TEST_PIN_FILE" "/Users/me/foo"
    add_pin "$TEST_PIN_FILE" "/Users/me/foo"
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 1 ]
}

# почему: see above. Trailing-slash equivalence prevents two
# different marker rows for the same project. Violation means the
# user can `browse` to `/Users/me/foo` and `/Users/me/foo/` and
# end up with both pinned.
@test "add_pin: trailing-slash path matches slashless existing" {
    add_pin "$TEST_PIN_FILE" "/Users/me/foo"
    add_pin "$TEST_PIN_FILE" "/Users/me/foo/"
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 1 ]
}

@test "add_pin: different paths accumulate" {
    add_pin "$TEST_PIN_FILE" "/Users/me/a"
    add_pin "$TEST_PIN_FILE" "/Users/me/b"
    add_pin "$TEST_PIN_FILE" "/Users/me/c"
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 3 ]
    [ "${PINS[0]}" = "/Users/me/a" ]
    [ "${PINS[1]}" = "/Users/me/b" ]
    [ "${PINS[2]}" = "/Users/me/c" ]
}
