#!/bin/bash
# Opt-in Ollama launch model selections; no downloads or account configuration.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${SKILLWEAVE_PYTHON:-python3}" "$REPO_DIR/scripts/setup_model_backend.py" ollama "$@"
