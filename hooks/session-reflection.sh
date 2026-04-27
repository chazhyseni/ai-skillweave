#!/bin/bash
# BMO-Style Session Reflection Hook
# Runs at session end to consolidate learning events into skills

set -e

echo "[REFLECTION] Session ending, consolidating learning..."

# Run consolidation script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONSOLIDATE_SCRIPT="$SCRIPT_DIR/scripts/consolidate-learning.py"

if [ -f "$CONSOLIDATE_SCRIPT" ]; then
  python3 "$CONSOLIDATE_SCRIPT"
else
  echo "[WARN] Consolidation script not found: $CONSOLIDATE_SCRIPT"
fi

exit 0
