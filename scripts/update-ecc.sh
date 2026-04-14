#!/bin/bash
# =============================================================================
# update-ecc.sh — Pull latest ECC skills and rebuild the cross-harness cache
# =============================================================================
# Run this when Everything Claude Code has been updated upstream to pull the
# latest skills without doing a full re-install.
#
# What it does:
#   1. git pull on ~/.claude-everything-claude-code
#   2. Rebuilds ~/.claude/skills-cache/combined-skills.txt
#   3. Re-syncs skills to all harness native directories (openclaw, pi, codex)
#
# Usage:
#   scripts/update-ecc.sh
#   scripts/update-ecc.sh --check   # check if update available, don't apply
# =============================================================================
set -e

ECC_DIR="$HOME/.claude-everything-claude-code"
SKILLS_CACHE_DIR="$HOME/.claude/skills-cache"
COMBINED_FILE="$SKILLS_CACHE_DIR/combined-skills.txt"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()     { echo -e "${BLUE}[ECC]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   ECC Skills Update                  ║"
echo "╚══════════════════════════════════════╝"
echo ""

ECC_REMOTE="https://github.com/affaan-m/everything-claude-code.git"

# =============================================================================
# Step 1: Ensure ECC is a git repo, then pull
# =============================================================================

if [ ! -d "$ECC_DIR" ]; then
    error "ECC not installed. Run: ./safe-install.sh"
fi

if [ ! -d "$ECC_DIR/.git" ]; then
    # ECC was installed by safe-install.sh (file copy, no .git) — add git tracking
    warn "ECC directory has no git history. Converting to a tracked git repo..."
    cd /tmp
    rm -rf ecc-update-tmp
    git clone --depth 1 "$ECC_REMOTE" ecc-update-tmp --quiet
    # Copy .git into ECC dir so future pulls work
    cp -r ecc-update-tmp/.git "$ECC_DIR/.git"
    cd "$ECC_DIR"
    # Mark all existing files as matching the current HEAD (avoid false diffs)
    git reset HEAD --quiet 2>/dev/null || true
    rm -rf /tmp/ecc-update-tmp
    success "Git tracking initialized for $ECC_DIR"
fi

log "Checking for ECC updates..."
cd "$ECC_DIR"

CURRENT=$(git rev-parse HEAD)
git fetch origin --quiet

REMOTE=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)

if [ "$CURRENT" = "$REMOTE" ]; then
    success "ECC already up to date ($(git log -1 --format='%h %s' HEAD))"
    if [[ "$*" != *"--check"* ]]; then
        echo ""
        log "Run with --force to rebuild cache anyway:"
        echo "  scripts/update-ecc.sh --force"
        echo ""
    fi
    [[ "$*" == *"--force"* ]] || exit 0
else
    BEHIND=$(git log HEAD..origin/main --oneline 2>/dev/null | wc -l | tr -d ' ')
    log "ECC has $BEHIND new commit(s). Pulling..."
    git pull origin main --quiet 2>/dev/null || git pull origin master --quiet
    NEW=$(git rev-parse HEAD)
    success "Updated: $(git log -1 --format='%h %s' HEAD)"
    echo ""
    log "New skills:"
    git diff "$CURRENT" "$NEW" --name-only -- skills/ | head -20
fi

[[ "$*" == *"--check"* ]] && exit 0

CURATED_DIR="$HOME/.claude-curated-skills"

# =============================================================================
# Step 2: Rebuild combined skills cache (matches safe-install.sh priority order)
# =============================================================================
log "Rebuilding skills cache..."
mkdir -p "$SKILLS_CACHE_DIR"
> "$COMBINED_FILE"

_add_skill_file() {
    echo "" >> "$COMBINED_FILE"
    sed '1,/^---$/d' "$1" | sed '1,/^---$/d' >> "$COMBINED_FILE"
}

# Priority 0: Learned skills (always first — your personal skills)
LEARNED_DIR="$HOME/.claude/skills/learned"
if [ -d "$LEARNED_DIR" ]; then
    LEARNED_COUNT=0
    for skill in "$LEARNED_DIR"/*.md; do
        [ -f "$skill" ] || continue
        _add_skill_file "$skill"
        LEARNED_COUNT=$((LEARNED_COUNT + 1))
    done
    [ $LEARNED_COUNT -gt 0 ] && success "Learned skills: $LEARNED_COUNT"
fi

# Priority 1: Anthropic Official (highest external quality)
if [ -d "$CURATED_DIR/anthropic-official" ]; then
    COUNT=0
    while IFS= read -r -d '' skill; do
        _add_skill_file "$skill"; COUNT=$((COUNT + 1))
    done < <(find "$CURATED_DIR/anthropic-official" -name "*.md" -type f -print0 2>/dev/null)
    [ $COUNT -gt 0 ] && success "Anthropic official skills: $COUNT"
fi

# Priority 2: OpenAI Codex skills (top 100 to keep context manageable)
if [ -d "$CURATED_DIR/openai-codex" ]; then
    COUNT=0
    while IFS= read -r -d '' skill; do
        [ $COUNT -ge 100 ] && break
        _add_skill_file "$skill"; COUNT=$((COUNT + 1))
    done < <(find "$CURATED_DIR/openai-codex" -name "*.md" -type f -print0 2>/dev/null)
    [ $COUNT -gt 0 ] && success "OpenAI Codex skills: $COUNT"
fi

# Priority 3: ECC skills (the core library)
if [ -d "$ECC_DIR/skills" ]; then
    SKILL_COUNT=0
    while IFS= read -r -d '' skill; do
        _add_skill_file "$skill"; SKILL_COUNT=$((SKILL_COUNT + 1))
    done < <(find "$ECC_DIR/skills" -name "*.md" -type f ! -path "*/learned/*" -print0 2>/dev/null)
    success "ECC skills: $SKILL_COUNT"
fi

# Priority 4: Community curated (top 50)
if [ -d "$CURATED_DIR/community-curated" ]; then
    COUNT=0
    while IFS= read -r -d '' skill; do
        [ $COUNT -ge 50 ] && break
        _add_skill_file "$skill"; COUNT=$((COUNT + 1))
    done < <(find "$CURATED_DIR/community-curated" -name "*.md" -type f -print0 2>/dev/null)
    [ $COUNT -gt 0 ] && success "Community curated skills: $COUNT"
fi

CACHE_SIZE=$(wc -c < "$COMBINED_FILE" | tr -d ' ')
success "Cache rebuilt: $CACHE_SIZE bytes → $COMBINED_FILE"

# =============================================================================
# Step 3: Re-sync to harness native skill directories
# =============================================================================
log "Re-syncing skills to harnesses..."

SYNCED=0

# OpenClaw: real file copies (not symlinks — OpenClaw rejects symlinks outside workspace)
OPENCLAW_WS="$HOME/.openclaw/workspace/skills"
if [ -d "$HOME/.openclaw/workspace" ]; then
    mkdir -p "$OPENCLAW_WS"
    for dir in "$ECC_DIR/skills"/*/; do
        skill_name=$(basename "$dir")
        [ ! -f "$dir/SKILL.md" ] && continue
        # Skip block scalars and extra fields (break openclaw YAML parser)
        grep -q '^description: *[>|]' "$dir/SKILL.md" 2>/dev/null && continue
        dst="$OPENCLAW_WS/$skill_name"
        # Update if ECC version is newer
        if [ ! -f "$dst/SKILL.md" ] || [ "$dir/SKILL.md" -nt "$dst/SKILL.md" ]; then
            mkdir -p "$dst"
            cp "$dir/SKILL.md" "$dst/SKILL.md"
            SYNCED=$((SYNCED + 1))
        fi
    done
    OC_COUNT=$(ls "$OPENCLAW_WS" 2>/dev/null | wc -l | tr -d ' ')
    success "OpenClaw: $OC_COUNT skills ($SYNCED updated)"
fi

# Pi and Codex: symlinks (they accept symlinks)
for harness_dir in "$HOME/.pi/agent/skills" "$HOME/.codex/skills"; do
    [ -d "$(dirname "$harness_dir")" ] || continue
    mkdir -p "$harness_dir"
    HARNESS_SYNCED=0
    for dir in "$ECC_DIR/skills"/*/; do
        skill_name=$(basename "$dir")
        [ ! -f "$dir/SKILL.md" ] && continue
        grep -q '^description: *[>|]' "$dir/SKILL.md" 2>/dev/null && continue
        if [ ! -e "$harness_dir/$skill_name" ]; then
            ln -s "$dir" "$harness_dir/$skill_name"
            HARNESS_SYNCED=$((HARNESS_SYNCED + 1))
        fi
    done
    HARNESS=$(basename "$(dirname "$harness_dir")")
    TOTAL=$(ls "$harness_dir" 2>/dev/null | wc -l | tr -d ' ')
    success "$HARNESS: $TOTAL skills ($HARNESS_SYNCED new links)"
done

echo ""
success "ECC update complete! Restart Claude Code and OpenClaw to load new skills."
echo ""
