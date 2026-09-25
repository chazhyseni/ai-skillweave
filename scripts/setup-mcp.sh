#!/bin/bash
# Merge available local MCP servers, preserving existing configuration.
set -eo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --force) ARGS+=(--force) ;;
        --help|-h) echo 'Usage: setup-mcp.sh [--force] (explicitly replace template server entries)'; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done
command -v python3 >/dev/null 2>&1 || { echo 'Python 3 is required.' >&2; exit 1; }
[ -f "$HOME/.claude.json" ] || { echo 'Run Claude Code once to initialize ~/.claude.json, then retry.' >&2; exit 1; }
exec python3 "$REPO_DIR/scripts/merge-mcp-config.py" "$REPO_DIR/configs/claude-mcp-servers.json" "$HOME/.claude.json" "${ARGS[@]}"
