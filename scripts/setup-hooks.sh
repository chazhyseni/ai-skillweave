#!/bin/bash
# =============================================================================
# setup-hooks.sh — Install Claude Code pre-tool-use hooks
# =============================================================================
# Installs ~/.claude/hooks/codesight-redirect.sh and registers it in
# ~/.claude/settings.json as a PreToolUse hook for Glob|Grep.
#
# The hook intercepts broad codebase searches and redirects Claude to call
# codesight_get_summary first when codesight is configured for the project.
# This enforces the "codesight before Grep/Glob" rule from CLAUDE.md via
# a hard block rather than just a soft instruction.
#
# Safe to re-run (idempotent).
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_SRC="$REPO_DIR/hooks/codesight-redirect.sh"
HOOK_DEST="$HOOKS_DIR/codesight-redirect.sh"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()     { echo -e "${BLUE}[HOOKS]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Install hook script
mkdir -p "$HOOKS_DIR"
cp "$HOOK_SRC" "$HOOK_DEST"
chmod +x "$HOOK_DEST"
success "Hook installed: $HOOK_DEST"

# Register in settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
fi

python3 << PYEOF
import json

settings_path = "$SETTINGS_FILE"
hook_path = "$HOOK_DEST"

with open(settings_path) as f:
    settings = json.load(f)

# Validate and fix malformed hooks structure
if "hooks" not in settings:
    settings["hooks"] = {}

# Fix any hook category that is not a list or contains entries without a "hooks" array
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
            # Fix malformed entry by adding empty hooks array
            entry["hooks"] = []
        cleaned.append(entry)
    settings["hooks"][hook_type] = cleaned

hook_entry = {
    "matcher": "Glob|Grep",
    "hooks": [{"type": "command", "command": hook_path}]
}

pre = settings["hooks"].get("PreToolUse", [])
# Remove stale codesight-redirect entries (idempotent)
pre = [h for h in pre if not any(
    hook.get("command", "").endswith("codesight-redirect.sh")
    for hook in h.get("hooks", [])
)]
pre.append(hook_entry)
settings["hooks"]["PreToolUse"] = pre

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print(f"PreToolUse hook registered in {settings_path}")
PYEOF

success "Hooks configured in $SETTINGS_FILE"
log "Effect: Claude will be redirected to call codesight_get_summary before broad Glob/Grep searches in codesight-enabled projects"
