#!/bin/bash
# Configure a local provider without overwriting gateway/auth/plugins/tools.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${SKILLWEAVE_PYTHON:-python3}" "$REPO_DIR/scripts/setup_model_backend.py" openclaw "$@"
