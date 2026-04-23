#!/bin/bash
# =============================================================================
# cleanup-invalid-skills.sh — Remove stale/invalid learned skills
# =============================================================================
# Deletes skills with:
#   - Names > 64 characters (truncated, invalid)
#   - Invalid YAML (mapping values not allowed, etc.)
#   - Empty/missing condition or strategy
#
# Safe to run (only touches learned skills, not curated/official).
# Moves deleted skills to ~/.claude/skills/learned/.archive/ instead of rm.
# =============================================================================
set -e

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()     { echo -e "${BLUE}[CLEANUP]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

ARCHIVE_DIR="$HOME/.claude/skills/learned/.archive"
mkdir -p "$ARCHIVE_DIR"

REMOVED=0
SKIPPED=0

# Function to check if a skill directory is invalid
check_skill_dir() {
    local dir="$1"
    local skill_name
    skill_name=$(basename "$dir")

    # Check 1: name length > 64
    if [ ${#skill_name} -gt 64 ]; then
        echo "INVALID: name too long (${#skill_name} chars)"
        return 0
    fi

    # Check 2: SKILL.md exists and has valid YAML front matter
    local skill_file="$dir/SKILL.md"
    if [ ! -f "$skill_file" ]; then
        echo "INVALID: missing SKILL.md"
        return 0
    fi

    # Check 3: YAML front matter integrity
    # Look for "invalid YAML" or truncated front matter
    if grep -q "invalid YAML" "$skill_file" 2>/dev/null; then
        echo "INVALID: corrupted YAML"
        return 0
    fi

    # Check 4: Empty or missing condition/strategy
    local has_condition
    has_condition=$(grep -c "^condition:" "$skill_file" 2>/dev/null || echo 0)
    local has_strategy
    has_strategy=$(grep -c "^strategy:" "$skill_file" 2>/dev/null || echo 0)
    if [ "$has_condition" -eq 0 ] || [ "$has_strategy" -eq 0 ]; then
        echo "INVALID: missing condition or strategy"
        return 0
    fi

    echo "OK"
    return 0
}

# Clean learned skills in Claude Code
CLAUDE_LEARNED="$HOME/.claude/skills/learned"
if [ -d "$CLAUDE_LEARNED" ]; then
    log "Checking Claude Code learned skills: $CLAUDE_LEARNED"
    for skill_dir in "$CLAUDE_LEARNED"/*; do
        [ -d "$skill_dir" ] || continue
        [ "$(basename "$skill_dir")" = ".archive" ] && continue

        status=$(check_skill_dir "$skill_dir")
        if [ "$status" != "OK" ]; then
            skill_name=$(basename "$skill_dir")
            warn "Removing $skill_name — $status"
            mv "$skill_dir" "$ARCHIVE_DIR/$skill_name-$(date +%s)"
            REMOVED=$((REMOVED + 1))
        else
            SKIPPED=$((SKIPPED + 1))
        fi
    done
fi

# Clean learned skills in Codex
CODEX_LEARNED="$HOME/.codex/skills"
if [ -d "$CODEX_LEARNED" ]; then
    log "Checking Codex learned skills: $CODEX_LEARNED"
    for skill_dir in "$CODEX_LEARNED"/*; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")

        # Only check skills that look like learned skills (long names or flat .md)
        if [ ${#skill_name} -gt 64 ]; then
            warn "Removing Codex skill $skill_name — name too long (${#skill_name} chars)"
            mv "$skill_dir" "$ARCHIVE_DIR/codex-$skill_name-$(date +%s)"
            REMOVED=$((REMOVED + 1))
            continue
        fi

        # Check for invalid YAML in flat .md files
        if [ -f "$skill_dir/SKILL.md" ]; then
            if grep -q "invalid YAML" "$skill_dir/SKILL.md" 2>/dev/null; then
                warn "Removing Codex skill $skill_name — corrupted YAML"
                mv "$skill_dir" "$ARCHIVE_DIR/codex-$skill_name-$(date +%s)"
                REMOVED=$((REMOVED + 1))
                continue
            fi
        fi

        SKIPPED=$((SKIPPED + 1))
    done
fi

# Clean learned skills in OpenClaw
OPENCLAW_LEARNED="$HOME/.openclaw/workspace/skills"
if [ -d "$OPENCLAW_LEARNED" ]; then
    log "Checking OpenClaw learned skills: $OPENCLAW_LEARNED"
    for skill_dir in "$OPENCLAW_LEARNED"/*; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")

        if [ ${#skill_name} -gt 64 ]; then
            warn "Removing OpenClaw skill $skill_name — name too long"
            mv "$skill_dir" "$ARCHIVE_DIR/openclaw-$skill_name-$(date +%s)"
            REMOVED=$((REMOVED + 1))
            continue
        fi

        if [ -f "$skill_dir/SKILL.md" ] && grep -q "invalid YAML" "$skill_dir/SKILL.md" 2>/dev/null; then
            warn "Removing OpenClaw skill $skill_name — corrupted YAML"
            mv "$skill_dir" "$ARCHIVE_DIR/openclaw-$skill_name-$(date +%s)"
            REMOVED=$((REMOVED + 1))
            continue
        fi

        SKIPPED=$((SKIPPED + 1))
    done
fi

# Clean learned skills in Pi
PI_LEARNED="$HOME/.pi/agent/skills"
if [ -d "$PI_LEARNED" ]; then
    log "Checking Pi learned skills: $PI_LEARNED"
    for skill_dir in "$PI_LEARNED"/*; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")

        if [ ${#skill_name} -gt 64 ]; then
            warn "Removing Pi skill $skill_name — name too long"
            mv "$skill_dir" "$ARCHIVE_DIR/pi-$skill_name-$(date +%s)"
            REMOVED=$((REMOVED + 1))
            continue
        fi

        if [ -f "$skill_dir/SKILL.md" ] && grep -q "invalid YAML" "$skill_dir/SKILL.md" 2>/dev/null; then
            warn "Removing Pi skill $skill_name — corrupted YAML"
            mv "$skill_dir" "$ARCHIVE_DIR/pi-$skill_name-$(date +%s)"
            REMOVED=$((REMOVED + 1))
            continue
        fi

        SKIPPED=$((SKIPPED + 1))
    done
fi

echo ""
success "Cleanup complete: $REMOVED invalid skills archived, $SKIPPED valid skills kept"
echo "  Archive: $ARCHIVE_DIR"
echo "  To restore: mv $ARCHIVE_DIR/<skill-name> <original-location>"
