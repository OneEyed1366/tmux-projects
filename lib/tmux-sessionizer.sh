#!/usr/bin/env bash
# Library of pure functions shared between bin/tmux-sessionizer and tests.
# Sourced, not executed. No top-level side effects.

# path_to_session_name <path> → <name>
#   Derive a tmux-safe session name from a directory path.
#   Leading dot is dropped entirely (~/.config → "config", not "_config").
#   Internal dots/spaces/colons/slashes become underscores so tmux's target
#   syntax (session.window.pane) doesn't get confused.
path_to_session_name() {
    local p="$1"
    local base
    base=$(basename "$p")
    base="${base#.}"
    # shellcheck disable=SC2001
    base=$(printf '%s' "$base" | tr ' .:/' '____')
    printf '%s' "$base"
}

# parse_roots <colon-separated-string> → sets global ROOTS array
#   Splits on colon, expands leading ~ and ~/ in each entry.
#   Empty input → leaves ROOTS empty (caller decides default).
parse_roots() {
    local input="$1"
    ROOTS=()
    if [[ -z "$input" ]]; then
        return 0
    fi
    IFS=':' read -r -a ROOTS <<< "$input"
    local i
    for i in "${!ROOTS[@]}"; do
        # shellcheck disable=SC2088  # ~ is a literal pattern, not an expansion
        case "${ROOTS[i]}" in
            "~") ROOTS[i]="$HOME" ;;
            "~/"*) ROOTS[i]="$HOME/${ROOTS[i]:2}" ;;
        esac
    done
}

# read_pins <file-path> → sets global PINS array
#   Parses pin file: comments (#), blank lines, trailing slashes stripped.
#   Missing file → PINS stays empty.
read_pins() {
    local file="$1"
    PINS=()
    [[ -f "$file" ]] || return 0
    local p
    while IFS= read -r p; do
        [[ -z "$p" || "$p" =~ ^[[:space:]]*# ]] && continue
        p="${p%/}"
        PINS+=("$p")
    done < "$file"
}

# add_pin <file-path> <path>
#   Appends <path> to the pin file if not already present (idempotent).
#   Trailing slash is stripped before comparison and write.
add_pin() {
    local file="$1"
    local p="$2"
    p="${p%/}"
    read_pins "$file"
    local existing
    for existing in "${PINS[@]}"; do
        if [[ "$existing" == "$p" ]]; then
            return 0
        fi
    done
    printf '%s\n' "$p" >> "$file"
}
