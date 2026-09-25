#!/bin/bash
# Optional user-local Ruflo CLI; never initializes projects or enables MCP servers.
set -euo pipefail
OFFLINE=false
for arg in "$@"; do
    case "$arg" in
        --offline) OFFLINE=true ;;
        --help|-h)
            echo 'Usage: bash scripts/setup-ruflo.sh [--offline]'
            echo 'Reuses an existing Ruflo CLI, or installs pinned Ruflo into ~/.local/share/ai-skillweave/ruflo.'
            echo 'Requires Node >=20 and npm for installation. No sudo, project init, or automatic MCP registration.'
            exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done
command -v node >/dev/null 2>&1 || { echo 'Ruflo requires Node.js >=20; install Node first.' >&2; exit 1; }
node -e 'if (Number(process.versions.node.split(".")[0]) < 20) process.exit(1)' || {
    echo 'Ruflo requires Node.js >=20; upgrade Node first.' >&2; exit 1;
}
PREFIX="$HOME/.local/share/ai-skillweave/ruflo"
CLI="$(type -P ruflo || true)"
if [ -n "$CLI" ]; then
    printf 'Preserving existing Ruflo: %s\n' "$CLI"
elif [ -x "$PREFIX/node_modules/.bin/ruflo" ] && [ -f "$PREFIX/.skillweave-installed" ]; then
    CLI="$PREFIX/node_modules/.bin/ruflo"
    printf 'Reusing user-local Ruflo: %s\n' "$CLI"
else
    if $OFFLINE; then
        echo 'Ruflo is not installed. Re-run --only ruflo without --offline to install it.' >&2
        exit 1
    fi
    command -v npm >/dev/null 2>&1 || { echo 'npm is required to install Ruflo.' >&2; exit 1; }
    # Use a dedicated package prefix: never change this project's package files or global npm packages.
    if [ -L "$PREFIX" ]; then echo "Refusing symlinked Ruflo install directory: $PREFIX" >&2; exit 1; fi
    mkdir -p "$PREFIX"
    npm install --prefix "$PREFIX" --save-exact --omit=dev --no-audit --no-fund \
        ruflo@3.45.0 @claude-flow/cli@3.45.0
    CLI="$PREFIX/node_modules/.bin/ruflo"
    [ -x "$CLI" ] || { echo 'npm completed without a Ruflo executable.' >&2; exit 1; }
    printf '%s\n' '3.45.0' > "$PREFIX/.skillweave-installed"
fi
"$CLI" --version
if [ "$CLI" = "$PREFIX/node_modules/.bin/ruflo" ]; then
    mkdir -p "$HOME/.local/bin"
    LINK="$HOME/.local/bin/ruflo"
    if [ ! -e "$LINK" ] && [ ! -L "$LINK" ]; then
        ln -s "$CLI" "$LINK"
    elif [ ! "$LINK" -ef "$CLI" ]; then
        printf 'Preserving existing launcher: %s; use the full CLI path below.\n' "$LINK"
    fi
    printf 'If needed, add %s to your PATH.\n' "$HOME/.local/bin"
fi
printf 'Ruflo ready: %s\n' "$CLI"
printf 'Project initialization and MCP registration were not run. Review `%s init --help` before opting in.\n' "$CLI"
