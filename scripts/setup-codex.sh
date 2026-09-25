#!/bin/bash
# Configure an opt-in, workspace-sandboxed local Codex profile.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${SKILLWEAVE_PYTHON:-python3}" "$REPO_DIR/scripts/setup_model_backend.py" codex "$@"
