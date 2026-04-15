#!/bin/bash
# =============================================================================
# setup-claude-md.sh — Install global CLAUDE.md for Claude Code
# =============================================================================
# Installs configs/global-claude-md.md to ~/.claude/CLAUDE.md
# This file is loaded into every Claude Code session's context and contains:
#   - Conciseness rules (reduce output tokens)
#   - Proactive MCP tool usage instructions (use codesight/token-optimizer/etc.)
#   - Token discipline guidelines
#
# Safe to re-run — merges with existing CLAUDE.md if present.
#
# Usage:
#   scripts/setup-claude-md.sh           # Install/merge
#   scripts/setup-claude-md.sh --force   # Overwrite existing
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_DIR/configs/global-claude-md.md"
TARGET="$HOME/.claude/CLAUDE.md"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()     { echo -e "${BLUE}[CLAUDE.md]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }

FORCE=false
[[ "$*" == *"--force"* ]] && FORCE=true

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   Global CLAUDE.md Setup             ║"
echo "╚══════════════════════════════════════╝"
echo ""

[ -f "$TEMPLATE" ] || { warn "Template not found: $TEMPLATE"; exit 1; }
mkdir -p "$(dirname "$TARGET")"

MARKER="# --- ai-skillweave managed section ---"
MARKER_END="# --- end ai-skillweave managed section ---"

if [ -f "$TARGET" ] && ! $FORCE; then
    # Check if our section already exists
    if grep -q "$MARKER" "$TARGET" 2>/dev/null; then
        # Replace our section
        python3 -c "
import re
with open('$TARGET') as f:
    content = f.read()
marker = '$MARKER'
marker_end = '$MARKER_END'
template = open('$TEMPLATE').read()
replacement = f'{marker}\n{template}\n{marker_end}'
pattern = re.escape(marker) + r'.*?' + re.escape(marker_end)
content = re.sub(pattern, replacement, content, flags=re.DOTALL)
with open('$TARGET', 'w') as f:
    f.write(content)
print('Updated existing managed section')
"
        success "Updated managed section in $TARGET"
    else
        # Append our section
        {
            echo ""
            echo "$MARKER"
            cat "$TEMPLATE"
            echo "$MARKER_END"
        } >> "$TARGET"
        success "Appended managed section to $TARGET"
    fi
else
    # Write fresh
    {
        echo "$MARKER"
        cat "$TEMPLATE"
        echo "$MARKER_END"
    } > "$TARGET"
    success "Created $TARGET"
fi

log "This file is loaded into every Claude Code session."
log "Claude will now proactively use MCP tools and produce concise output."
echo ""
