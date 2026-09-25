#!/bin/bash
# Add a native OMP models.yml provider without changing selected model roles.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${SKILLWEAVE_PYTHON:-python3}" "$REPO_DIR/scripts/setup_model_backend.py" omp "$@"
