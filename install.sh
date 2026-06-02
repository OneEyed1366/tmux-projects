#!/usr/bin/env bash
# Install tmux-sessionizer to ~/.local/bin (or $PREFIX/bin).
# Standalone — no `make` required.

set -euo pipefail

# ---- Args / env --------------------------------------------------------

PREFIX="${PREFIX:-$HOME/.local}"
BINDIR="${BINDIR:-$PREFIX/bin}"
LIBDIR="${LIBDIR:-$PREFIX/lib}"
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_SRC="$REPO_ROOT/bin/tmux-sessionizer"
LIB_SRC="$REPO_ROOT/lib/tmux-sessionizer.sh"
TARGET="$BINDIR/tmux-sessionizer"
LIB_TARGET="$LIBDIR/tmux-sessionizer.sh"

usage() {
    cat <<EOF
Usage: install.sh [OPTIONS]

Install tmux-sessionizer to a directory on PATH.

OPTIONS:
    -h, --help       Show this help
    --prefix DIR     Install under DIR (default: \$HOME/.local)
    --bindir DIR     Install into DIR (default: \$PREFIX/bin)
    --libdir DIR     Install lib into DIR (default: \$PREFIX/lib)

ENVIRONMENT:
    PREFIX, BINDIR, LIBDIR   Same as --prefix / --bindir / --libdir

EXAMPLES:
    ./install.sh
    PREFIX=/usr/local ./install.sh
    ./install.sh --bindir /opt/homebrew/bin
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

# ---- Pre-flight --------------------------------------------------------

if [[ ! -r "$SCRIPT_SRC" ]]; then
    echo "Cannot read source script: $SCRIPT_SRC" >&2
    echo "Run install.sh from the repo root." >&2
    exit 1
fi

if [[ ! -r "$LIB_SRC" ]]; then
    echo "Cannot read lib: $LIB_SRC" >&2
    echo "Run install.sh from the repo root." >&2
    exit 1
fi

for d in "$BINDIR" "$LIBDIR"; do
    if [[ ! -d "$d" ]]; then
        if ! mkdir -p -- "$d" 2>/dev/null; then
            echo "Cannot create $d — try a different --bindir/--libdir or PREFIX." >&2
            exit 1
        fi
        echo "Created directory: $d"
    fi
done

# ---- Install -----------------------------------------------------------

install -m 0755 "$SCRIPT_SRC" "$TARGET"
echo "Installed: $TARGET"
install -m 0644 "$LIB_SRC" "$LIB_TARGET"
echo "Installed: $LIB_TARGET"

# ---- Post-install smoke check ------------------------------------------

if ! "$TARGET" --version >/dev/null 2>&1; then
    echo "Warning: installed script failed --version check." >&2
    echo "This usually means a missing interpreter or broken PATH." >&2
    exit 1
fi
INSTALLED_VERSION="$("$TARGET" --version)"
echo "Verified:  $INSTALLED_VERSION"

# ---- PATH hint ---------------------------------------------------------

case ":$PATH:" in
    *":$BINDIR:"*) ;;
    *)
        echo
        echo "Note: $BINDIR is not on your PATH."
        echo "Add it to your shell rc:"
        echo "    export PATH=\"$BINDIR:\$PATH\""
        ;;
esac
