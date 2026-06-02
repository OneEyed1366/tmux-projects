#!/usr/bin/env bash
# Remove tmux-sessionizer from ~/.local/bin (or $PREFIX/bin).
# Idempotent — does not fail if the file is not installed.
# Standalone — no `make` required.

set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
BINDIR="${BINDIR:-$PREFIX/bin}"
LIBDIR="${LIBDIR:-$PREFIX/lib}"
TARGET="$BINDIR/tmux-sessionizer"
LIB_TARGET="$LIBDIR/tmux-sessionizer.sh"

usage() {
    cat <<EOF
Usage: uninstall.sh [OPTIONS]

Remove the installed tmux-sessionizer.

OPTIONS:
    -h, --help       Show this help
    --prefix DIR     Uninstall from under DIR (default: \$HOME/.local)
    --bindir DIR     Look in DIR (default: \$PREFIX/bin)
    --libdir DIR     Look in DIR (default: \$PREFIX/lib)

EXAMPLES:
    ./uninstall.sh
    PREFIX=/usr/local ./uninstall.sh
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --prefix)  PREFIX="$2"; BINDIR="$PREFIX/bin"; LIBDIR="$PREFIX/lib"; shift 2 ;;
        --bindir)  BINDIR="$2"; shift 2 ;;
        --libdir)  LIBDIR="$2"; shift 2 ;;
        --) shift; break ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
        *) break ;;
    esac
done

removed=0
for f in "$TARGET" "$LIB_TARGET"; do
    if [[ -e "$f" ]]; then
        rm -f -- "$f"
        echo "Removed: $f"
        removed=1
    fi
done

if [[ $removed -eq 0 ]]; then
    echo "Not installed at: $TARGET (or $LIB_TARGET)"
    echo "(nothing to do — idempotent)"
fi
