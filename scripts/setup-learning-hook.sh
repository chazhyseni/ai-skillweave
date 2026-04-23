#!/bin/bash
# Setup BMO-style learning capture hook in Claude Code settings

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_PATH="$REPO_DIR/hooks/learning-capture.sh"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "[WARN] Claude Code settings not found: $SETTINGS_FILE"
  echo "Run Claude Code once to initialize, then re-run this script"
  exit 1
fi

if [ ! -f "$HOOK_PATH" ]; then
  echo "[ERROR] Learning capture hook not found: $HOOK_PATH"
  exit 1
fi

python3 << PYEOF
import json
from pathlib import Path

settings_file = Path.home() / ".claude" / "settings.json"
hook_path = "$HOOK_PATH"

try:
    with open(settings_file) as f:
        settings = json.load(f)
    
    # Validate and fix malformed hooks structure
    if "hooks" not in settings:
        settings["hooks"] = {}
    
    for hook_type in list(settings["hooks"].keys()):
        entries = settings["hooks"][hook_type]
        if not isinstance(entries, list):
            settings["hooks"][hook_type] = []
            continue
        cleaned = []
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            if "hooks" not in entry or not isinstance(entry["hooks"], list):
                entry["hooks"] = []
            cleaned.append(entry)
        settings["hooks"][hook_type] = cleaned
    
    if "UserPromptSubmit" not in settings["hooks"]:
        settings["hooks"]["UserPromptSubmit"] = []
    
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
