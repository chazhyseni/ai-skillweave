#!/bin/bash
# Read-only verification. Optional --probe-url explicitly probes a local model API.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="${SKILLWEAVE_PYTHON:-$HOME/.claude/skillweave-venv/bin/python}"
if [ ! -x "$PYTHON" ]; then PYTHON="${SKILLWEAVE_PYTHON:-python3}"; fi
exec "$PYTHON" -B "$SCRIPT_DIR/verify_setup.py" "$@"
