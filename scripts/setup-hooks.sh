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

command -v python3 >/dev/null 2>&1 || { echo 'Python 3 is required.' >&2; exit 1; }
if [ "$#" -gt 0 ]; then
    case "$1" in --help|-h) echo 'Usage: setup-hooks.sh'; exit 0 ;; *) echo "Unknown option: $1" >&2; exit 1 ;; esac
fi
mkdir -p "$HOOKS_DIR"
if [ -e "$HOOK_DEST" ] && ! cmp -s "$HOOK_SRC" "$HOOK_DEST"; then
    warn "Preserving existing hook: $HOOK_DEST (review manually to update)"
else
    cp "$HOOK_SRC" "$HOOK_DEST"
    chmod +x "$HOOK_DEST"
fi

# Register in settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
fi

python3 - "$SETTINGS_FILE" "$HOOK_DEST" <<'PYEOF'
import json, shlex, sys

settings_path = sys.argv[1]
hook_path = sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

# Reject malformed settings rather than erasing unrelated user hooks.
settings.setdefault("hooks", {})
if not isinstance(settings["hooks"], dict):
    raise SystemExit("Existing hooks must be an object; configuration unchanged.")
pre = settings["hooks"].get("PreToolUse", [])
if not isinstance(pre, list) or any(not isinstance(h, dict) or not isinstance(h.get("hooks"), list) for h in pre):
    raise SystemExit("Existing PreToolUse hooks are malformed; configuration unchanged.")

hook_entry = {
    "matcher": "Glob|Grep",
    "hooks": [{"type": "command", "command": shlex.quote(hook_path)}]
}

if any(h.get("command") in (hook_path, shlex.quote(hook_path)) for entry in pre for h in entry["hooks"]):
    print("Existing codesight hook preserved")
    sys.exit(0)
pre.append(hook_entry)
settings["hooks"]["PreToolUse"] = pre

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print(f"PreToolUse hook registered in {settings_path}")
PYEOF

success "Hooks configured in $SETTINGS_FILE"
log "Effect: Claude will be redirected to call codesight_get_summary before broad Glob/Grep searches in codesight-enabled projects"
