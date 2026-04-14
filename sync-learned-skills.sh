#!/bin/bash
# =============================================================================
# Cross-Harness Skill Learner & Sync
# =============================================================================
# 1. Extracts learned patterns from all harness conversation histories
# 2. Writes new skills to ~/.claude/skills/learned/
# 3. Syncs learned skills to all harnesses (codex, pi, openclaw)
#
# Usage:
#   ~/scripts/agent_harness_modifications/sync-learned-skills.sh           # full sync
#   ~/scripts/agent_harness_modifications/sync-learned-skills.sh --dry-run # preview only
#   ~/scripts/agent_harness_modifications/sync-learned-skills.sh --verbose # detailed output
# =============================================================================

set -e

DRY_RUN=false
VERBOSE=false
EXTRACTOR="$HOME/scripts/agent_harness_modifications/extract-conversation-skills.py"
LEARNED_DIR="$HOME/.claude/skills/learned"
LOG_FILE="$HOME/scripts/agent_harness_modifications/shared-learnings/sync.log"
LEARNINGS_MD="$HOME/scripts/agent_harness_modifications/shared-learnings/learnings.md"

# Colors
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()     { echo -e "${BLUE}[LEARN]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
info()    { echo -e "${CYAN}[INFO]${NC} $1"; }

for arg in "$@"; do
    case $arg in --dry-run) DRY_RUN=true ;;
                 --verbose) VERBOSE=true ;;
    esac
done

mkdir -p "$HOME/scripts/agent_harness_modifications/shared-learnings"
mkdir -p "$LEARNED_DIR"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Cross-Harness Skill Learner                           ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
log "Started: $(date)"

# =============================================================================
# Step 1: Extract learned skills from all harness histories
# =============================================================================

log "Step 1: Extracting patterns from conversation histories..."

if [ ! -f "$EXTRACTOR" ]; then
    warn "Extractor not found: $EXTRACTOR"
    warn "Skipping extraction — will still sync existing learned skills"
else
    EXTRACT_ARGS="--output $LEARNED_DIR"
    $VERBOSE && EXTRACT_ARGS="$EXTRACT_ARGS --verbose"
    $DRY_RUN && EXTRACT_ARGS="$EXTRACT_ARGS --dry-run"

    # Extract from claude history
    if [ -f "$HOME/.claude/history.jsonl" ] || [ -d "$HOME/.claude/sessions" ]; then
        python3 "$EXTRACTOR" $EXTRACT_ARGS 2>/dev/null && \
            success "Extracted from claude history" || \
            warn "No new patterns found in claude history"
    fi

    # Extract from openclaw memory (daily notes)
    if [ -d "$HOME/.openclaw/workspace/memory" ]; then
        for mem_file in "$HOME/.openclaw/workspace/memory"/*.md; do
            [ -f "$mem_file" ] || continue
            # Copy memory insights to learnings log
            echo "## From OpenClaw memory: $(basename $mem_file)" >> "$LEARNINGS_MD" 2>/dev/null || true
        done
        success "Indexed openclaw memory files"
    fi
fi

LEARNED_COUNT=$(ls "$LEARNED_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
log "Current learned skills: $LEARNED_COUNT"

# =============================================================================
# Step 2: Sync learned skills to all harnesses
# =============================================================================

log "Step 2: Syncing learned skills to all harnesses..."
SYNCED=0

sync_skill_to_harness() {
    local src_file="$1"
    local dst_dir="$2"
    local harness="$3"
    local skill_name
    skill_name=$(basename "$src_file" .md)

    # Skills in learned/ are flat .md files — each harness needs a dir/SKILL.md structure
    local dst_skill_dir="$dst_dir/$skill_name"

    if $DRY_RUN; then
        info "  [dry-run] Would sync: $skill_name → $harness"
        return 0
    fi

    # Check if already synced (compare modification time)
    if [ -f "$dst_skill_dir/SKILL.md" ] && \
       [ "$src_file" -ot "$dst_skill_dir/SKILL.md" ]; then
        $VERBOSE && info "  Up-to-date: $skill_name in $harness"
        return 0
    fi

    # Convert flat .md to skill directory format
    mkdir -p "$dst_skill_dir"
    cp "$src_file" "$dst_skill_dir/SKILL.md"
    info "  Synced: $skill_name → $harness"
    SYNCED=$((SYNCED + 1))
}

# Sync to codex
if [ -d "$HOME/.codex/skills" ]; then
    for skill_file in "$LEARNED_DIR"/*.md; do
        [ -f "$skill_file" ] || continue
        sync_skill_to_harness "$skill_file" "$HOME/.codex/skills" "codex"
    done
    success "Codex: synced"
fi

# Sync to pi
if [ -d "$HOME/.pi/agent/skills" ]; then
    for skill_file in "$LEARNED_DIR"/*.md; do
        [ -f "$skill_file" ] || continue
        sync_skill_to_harness "$skill_file" "$HOME/.pi/agent/skills" "pi"
    done
    success "Pi: synced"
fi

# Sync to openclaw workspace skills (real files, not symlinks)
OPENCLAW_WS_SKILLS="$HOME/.openclaw/workspace/skills"
if [ -d "$HOME/.openclaw/workspace" ]; then
    mkdir -p "$OPENCLAW_WS_SKILLS"
    for skill_file in "$LEARNED_DIR"/*.md; do
        [ -f "$skill_file" ] || continue
        skill_name=$(basename "$skill_file" .md)
        dst_dir="$OPENCLAW_WS_SKILLS/$skill_name"
        if $DRY_RUN; then
            info "  [dry-run] Would sync: $skill_name → openclaw"
        elif [ ! -f "$dst_dir/SKILL.md" ] || [ "$skill_file" -nt "$dst_dir/SKILL.md" ]; then
            mkdir -p "$dst_dir"
            cp "$skill_file" "$dst_dir/SKILL.md"
            info "  Synced: $skill_name → openclaw"
            SYNCED=$((SYNCED + 1))
        fi
    done
    success "OpenClaw: synced"
fi

# Also update ~/.claude/skills/ for claude /skills dialog (symlinks)
CLAUDE_SKILLS_LEARNED="$HOME/.claude/skills/learned"
if [ -d "$HOME/.claude/skills" ] && [ ! -d "$CLAUDE_SKILLS_LEARNED" ]; then
    ln -sfn "$LEARNED_DIR" "$CLAUDE_SKILLS_LEARNED" 2>/dev/null || true
fi

# =============================================================================
# Step 3: Update learnings log
# =============================================================================

log "Step 3: Updating shared learnings log..."
{
    echo ""
    echo "## Sync: $(date)"
    echo "- Learned skills total: $LEARNED_COUNT"
    echo "- Newly synced: $SYNCED"
    echo "- Harnesses updated: codex, pi, openclaw"
} >> "$LEARNINGS_MD" 2>/dev/null || true

# Log to file
echo "$(date) | learned=$LEARNED_COUNT synced=$SYNCED dry_run=$DRY_RUN" >> "$LOG_FILE" 2>/dev/null || true

echo ""
if $DRY_RUN; then
    warn "DRY RUN — no changes written"
else
    success "Sync complete: $SYNCED skills propagated across harnesses"
    success "Learned skills total: $LEARNED_COUNT"
fi
echo ""
