#!/bin/bash
# Setup BMO-style learning capture hook in Claude Code settings

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_PATH="$REPO_DIR/hooks/learning-capture.sh"
command -v python3 >/dev/null 2>&1 || { echo 'Python 3 is required.' >&2; exit 1; }
if [ "$#" -gt 0 ]; then
  case "$1" in --help|-h) echo 'Usage: setup-learning-hook.sh'; exit 0 ;; *) echo "Unknown option: $1" >&2; exit 1 ;; esac
fi

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "[WARN] Claude Code settings not found: $SETTINGS_FILE"
  echo "Run Claude Code once to initialize, then re-run this script"
  exit 1
fi

if [ ! -f "$HOOK_PATH" ]; then
  echo "[ERROR] Learning capture hook not found: $HOOK_PATH"
  exit 1
fi

python3 - "$HOOK_PATH" <<'PYEOF'
import json, shlex, sys
from pathlib import Path

settings_file = Path.home() / ".claude" / "settings.json"
hook_path = shlex.quote(sys.argv[1])

try:
    with open(settings_file) as f:
        settings = json.load(f)
    
    # Preserve unrelated hooks and reject malformed structures without rewriting.
    settings.setdefault("hooks", {})
    if not isinstance(settings["hooks"], dict):
        raise ValueError("Existing hooks must be an object")
    settings["hooks"].setdefault("UserPromptSubmit", [])
    entries = settings["hooks"]["UserPromptSubmit"]
    if not isinstance(entries, list) or any(not isinstance(e, dict) or not isinstance(e.get("hooks"), list) for e in entries):
        raise ValueError("Existing UserPromptSubmit hooks are malformed")
    
    # Add learning capture hook if not already present
    hook_exists = any(
        any(hook.get("command") == hook_path for hook in entry.get("hooks", []))
        for entry in settings["hooks"]["UserPromptSubmit"]
    )
    if not hook_exists:
        settings["hooks"]["UserPromptSubmit"].append({
            "matcher": "*",
            "hooks": [{"type": "command", "command": hook_path}]
        })
        with open(settings_file, "w") as f:
            json.dump(settings, f, indent=2)
        print(f"[OK] Added learning-capture hook to {settings_file}")
    else:
        print(f"[OK] Learning-capture hook already present in {settings_file}")
except Exception as e:
    print(f"[ERROR] Could not update settings.json: {e}")
    exit(1)
PYEOF
