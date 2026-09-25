#!/bin/bash
# Add a native OMP models.yml provider without changing selected model roles.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${SKILLWEAVE_PYTHON:-$HOME/.claude/skillweave-venv/bin/python}"
if [ ! -x "$PYTHON" ]; then PYTHON="${SKILLWEAVE_PYTHON:-python3}"; fi
exec "$PYTHON" -B "$REPO_DIR/scripts/setup_model_backend.py" omp "$@"
