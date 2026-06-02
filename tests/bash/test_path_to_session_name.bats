#!/usr/bin/env bats
#
# Unit tests for path_to_session_name (lib/tmux-sessionizer.sh).
# Mirrors the table in share/SPEC.md — keep these in sync.

setup() {
    LIB="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/lib/tmux-sessionizer.sh"
    source "$LIB"
}

# почему: leading-dot rule. `~/.config` is the canonical user-dotfiles
# location; "config" is more readable than "_config" and matches the
# user's mental model. Dropping the dot also avoids tmux target syntax
# confusion (a leading dot in a session name has no special meaning,
# but the user picks by path, not by session name).
@test "path_to_session_name: leading dot in basename is dropped" {
    [ "$(path_to_session_name "$HOME/.config")" = "config" ]
    [ "$(path_to_session_name "/Users/x/.ssh")" = "ssh" ]
}

# почему: tmux's `session.window.pane` target syntax uses `.` as the
# separator. A space in the session name would either fail or be
# confused for the separator; underscore is the safe tmux-friendly
# transliteration.
@test "path_to_session_name: spaces in basename become underscores" {
    [ "$(path_to_session_name "$HOME/my project")" = "my_project" ]
}

# почему: same reason as spaces — `.` is a tmux target separator, and
# `/` would be parsed as a window/pane boundary. Basename only because
# the session represents the project (leaf), not the file path.
@test "path_to_session_name: dots in basename become underscores" {
    [ "$(path_to_session_name "$HOME/a.b/c.d")" = "c_d" ]
}

# почему: `:` is the tmux target separator (along with `.`). Slashes
# in basename would also be parsed as window/pane boundary.
@test "path_to_session_name: colons and slashes in basename become underscores" {
    [ "$(path_to_session_name "/var/log:weird")" = "log_weird" ]
}

@test "path_to_session_name: simple basename unchanged" {
    [ "$(path_to_session_name "/var/log")" = "log" ]
    [ "$(path_to_session_name "$HOME/projects")" = "projects" ]
}

# почему: session name reflects the project, not the filesystem depth.
# A user with `~/Code/a/b/c/d/e/foo` still wants the session called
# "foo".
@test "path_to_session_name: nested path uses only basename" {
    [ "$(path_to_session_name "/very/deep/nested/path/foo")" = "foo" ]
}

# почему: SYMMETRY with the lua impl. coreutils `basename(1)` strips
# trailing slashes; the lua impl uses `vim.fn.fnamemodify(p, ":t")`
# which returns "" for trailing-slash input. The lua impl has an
# explicit `gsub("/+$", "")` to match this behavior. If this bash
# test ever fails, either bash's `basename` changed, or someone
# removed the strip from one of the two impls.
@test "path_to_session_name: trailing slash is irrelevant" {
    [ "$(path_to_session_name "$HOME/projects/")" = "projects" ]
}

# почему: defensive. A cleared fzf input should not silently produce
# a session. The picker wraps this in `selected="${picked:-$query}"`
# so empty → exit 0; this is the boundary check on the function
# itself.
@test "path_to_session_name: empty input → empty output" {
    [ -z "$(path_to_session_name "")" ]
}
