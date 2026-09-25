#!/bin/bash
# Update enabled upstream checkouts and deliver complete skills to native harness roots.
# --check/--dry-run never fetch or write; --offline syncs existing trees without network.
# See --help for source selection, opt-outs, --harness and safe --uninstall.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="${SKILLWEAVE_PYTHON:-$HOME/.claude/skillweave-venv/bin/python}"
if [ ! -x "$PYTHON" ]; then
    PYTHON="${SKILLWEAVE_PYTHON:-python3}"
fi
exec "$PYTHON" -B "$SCRIPT_DIR/skill_sync.py" "$@"
