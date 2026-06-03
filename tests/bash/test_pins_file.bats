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

# почему: REMOVAL = DEDUP'S MIRROR. If the picker lets users pin a path
# but never unpin it, the "delete project" picker action is a lie. The
# pin file must shrink on unpin or stale entries haunt the picker.
@test "unpin: removes the target path" {
    add_pin "$TEST_PIN_FILE" "/Users/me/a"
    add_pin "$TEST_PIN_FILE" "/Users/me/b"
    add_pin "$TEST_PIN_FILE" "/Users/me/c"
    unpin "$TEST_PIN_FILE" "/Users/me/b"
    [ "$REMOVED" -eq 1 ]
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 2 ]
    [ "${PINS[0]}" = "/Users/me/a" ]
    [ "${PINS[1]}" = "/Users/me/c" ]
}

# почему: removing the only entry should leave an empty file (not
# delete the file). The picker reads PINS=[] from a missing or empty
# file, but the file's existence vs. absence is observable to other
# tools (e.g. `--validate` checks the dir). Preserve the file.
@test "unpin: removes the only entry, file stays empty" {
    add_pin "$TEST_PIN_FILE" "/Users/me/solo"
    unpin "$TEST_PIN_FILE" "/Users/me/solo"
    [ "$REMOVED" -eq 1 ]
    [ -f "$TEST_PIN_FILE" ]
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 0 ]
}

# почему: the picker action is idempotent UX-wise — pressing `d` on
# a project that's already gone must not error. The contract: silent
# no-op with REMOVED=0. Violation = an error toast every time the
# user clicks an already-deleted row, which is annoying.
@test "unpin: idempotent — unpinning an absent path is a no-op" {
    unpin "$TEST_PIN_FILE" "/Users/me/never-pinned"
    [ "$REMOVED" -eq 0 ]
}

# почему: unpin on a never-created file (e.g. user has never browsed)
# must not error and must not create the file. Creating an empty file
# here would be a side effect with no caller asking for it.
@test "unpin: missing file is a silent no-op" {
    rm -f "$TEST_PIN_FILE"
    unpin "$TEST_PIN_FILE" "/Users/me/anything"
    [ "$REMOVED" -eq 0 ]
    [ ! -f "$TEST_PIN_FILE" ]
}

# почему: same slash-stripping contract as add_pin. The picker
# stores paths slashless; if unpin didn't strip, the user's
# `d` action on a path added via the OS picker (which may give
# `/foo/`) would silently fail to match. See add_pin:trailing-slash
# test for the symmetric case.
@test "unpin: trailing-slash path matches slashless existing" {
    add_pin "$TEST_PIN_FILE" "/Users/me/foo"
    unpin "$TEST_PIN_FILE" "/Users/me/foo/"
    [ "$REMOVED" -eq 1 ]
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 0 ]
}

# почему: comments and blank lines must survive unpin. read_pins
# strips them from PINS but they live in the file. A naive rewrite
# that only writes PINS[] would erase user comments — silent data
# loss on every delete.
@test "unpin: preserves comments and blank lines in the file" {
    cat > "$TEST_PIN_FILE" <<EOF
# my curated list
/Users/me/foo

# /Users/me/commented-out
/Users/me/bar
EOF
    unpin "$TEST_PIN_FILE" "/Users/me/foo"
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 1 ]
    [ "${PINS[0]}" = "/Users/me/bar" ]
    # Header comment must still be there.
    grep -qF '# my curated list' "$TEST_PIN_FILE"
    grep -qF '# /Users/me/commented-out' "$TEST_PIN_FILE"
}

# почему: pin files written by external tools (or hand-edited in
# editors that don't auto-add a trailing newline) may lack a final
# `\n`. The `read -r line || [[ -n "$line" ]]` clause in unpin() is
# the bash equivalent of lua's `lines("*L")` — both must handle the
# unterminated last line, or that line is silently dropped on every
# delete. SYMMETRY with the lua side's pins_spec test.
#
# Byte-exact check: `cmp` compares the file to an expected byte
# sequence. If the rewrite silently adds a trailing `\n` (or drops
# one), this test fails. Lock-in for the contract documented in
# share/SPEC.md.
@test "unpin: preserves file's trailing-newline state (no newline)" {
    printf '/Users/me/a\n/Users/me/b' > "$TEST_PIN_FILE" # no final \n
    unpin "$TEST_PIN_FILE" "/Users/me/a"
    [ "$REMOVED" -eq 1 ]
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 1 ]
    [ "${PINS[0]}" = "/Users/me/b" ]
    # Byte-exact: must be exactly /Users/me/b, no trailing newline
    local expected
    expected=$(mktemp)
    printf '/Users/me/b' > "$expected"
    cmp -s "$TEST_PIN_FILE" "$expected"
    [ "$?" -eq 0 ]
    rm -f "$expected"
}

# почему: symmetric case — file with trailing newline must keep it
# after unpin. The rewrite contract in share/SPEC.md: "A file with
# one keeps one." Without the `has_trailing_nl=1` branch in unpin,
# this would still pass (printf always adds \n), but the parallel
# test pins the other half of the contract.
@test "unpin: preserves file's trailing-newline state (with newline)" {
    printf '/Users/me/a\n/Users/me/b\n' > "$TEST_PIN_FILE" # has \n
    unpin "$TEST_PIN_FILE" "/Users/me/a"
    [ "$REMOVED" -eq 1 ]
    read_pins "$TEST_PIN_FILE"
    [ "${#PINS[@]}" -eq 1 ]
    [ "${PINS[0]}" = "/Users/me/b" ]
    # Byte-exact: must be exactly /Users/me/b\n
    local expected
    expected=$(mktemp)
    printf '/Users/me/b\n' > "$expected"
    cmp -s "$TEST_PIN_FILE" "$expected"
    [ "$?" -eq 0 ]
    rm -f "$expected"
}
