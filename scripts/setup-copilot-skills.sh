#!/bin/bash
# Copilot personal discovery is ~/.copilot/skills/<name>/SKILL.md.
# Keep custom skills active; never replace its entire directory or sanitize sources.
# --check is a read-only offline preview; --unlink removes only unchanged owned files.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGS=(--offline --harness copilot)
for arg in "$@"; do
    case "$arg" in
        --unlink) ARGS+=(--uninstall) ;;
        *) ARGS+=("$arg") ;;
    esac
done
exec bash "$SCRIPT_DIR/update-ecc.sh" "${ARGS[@]}"
