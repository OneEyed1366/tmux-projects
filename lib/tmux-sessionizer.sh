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
#   Handles a file that lacks a final `\n` (e.g. created by an
#   external tool that doesn't auto-terminate). SYMMETRY with
#   `pins.lua::M.read` and `lib/tmux-sessionizer.sh::unpin` —
#   all three must tolerate unterminated last line.
read_pins() {
    local file="$1"
    PINS=()
    [[ -f "$file" ]] || return 0
    local p
    while IFS= read -r p || [[ -n "$p" ]]; do
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

# unpin <file-path> <path>
#   Removes <path> from the pin file (idempotent: no-op if absent).
#   Trailing slash is stripped before comparison.
#   Line-preserving rewrite: comments, blank lines, and ordering of the
#   remaining entries survive untouched. The pin file is the user's
#   curated hide list — silently dropping their `#` annotations on every
#   delete would be data loss.
#   Atomic via temp file + mv: a crash mid-rewrite leaves the original
#   intact, not half-written. Torn pin files silently drop pins.
#   Sets REMOVED=1 if a matching line was deleted, 0 otherwise — callers
#   can use this to decide whether to also kill the matching tmux session.
unpin() {
    local file="$1"
    local p="$2"
    p="${p%/}"
    REMOVED=0

    # Nothing to remove when the file doesn't exist.
    [[ -f "$file" ]] || return 0

    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/tmux-projects.XXXXXX")
    # Best-effort cleanup if we abort before mv.
    trap 'rm -f "$tmp"' RETURN

    # Detect whether the file ends with a newline. Rewrite must
    # preserve the file's exact byte sequence — comments, blank
    # lines, surrounding whitespace, AND the trailing-newline
    # state. Mirrors the lua side's `lines("*L")` write-through.
    # Without this, a file without a final `\n` would silently
    # gain one on every delete — same class of bug as dropping
    # a `#` comment.
    #
    # NB: `$(tail -c 1 file)` strips the trailing newline via
    # command substitution, so we can't use it directly to compare
    # against `$'\n'`. Pipe through `od -tx1` instead — od reads
    # bytes without any shell-level newline handling. Hex `0a` =
    # `\n`.
    local has_trailing_nl=0
    if [[ -s "$file" ]]; then
        local last_hex
        last_hex=$(tail -c 1 "$file" 2>/dev/null | od -An -tx1 | tr -d ' \n')
        if [[ "$last_hex" == "0a" ]]; then
            has_trailing_nl=1
        fi
    fi

    # Stream the file line-by-line: copy through everything except the
    # line whose slashless trimmed form equals the target path. This
    # preserves comments, blank lines, and surrounding whitespace verbatim.
    local line trimmed
    while IFS= read -r line || [[ -n "$line" ]]; do
        trimmed="${line#"${line%%[![:space:]]*}"}"   # ltrim
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"  # rtrim
        trimmed="${trimmed%/}"
        if [[ "$trimmed" == "$p" ]]; then
            REMOVED=1
            continue
        fi
        printf '%s\n' "$line" >> "$tmp"
    done < "$file"

    # Idempotent: path wasn't pinned, leave the file alone.
    if [[ "$REMOVED" -eq 0 ]]; then
        rm -f -- "$tmp"
        trap - RETURN
        return 0
    fi

    # If the original file lacked a trailing newline, strip the
    # one our `printf '%s\n'` above added. Matches the lua side's
    # `*L` write-through (both preserve the user's exact byte
    # sequence).
    if [[ $has_trailing_nl -eq 0 && -s "$tmp" ]]; then
        local sz
        sz=$(wc -c < "$tmp")
        if [[ $sz -gt 0 ]]; then
            head -c $((sz - 1)) "$tmp" > "$tmp.no_nl"
            mv "$tmp.no_nl" "$tmp"
        fi
    fi

    mv -- "$tmp" "$file"
    trap - RETURN
}
