#!/bin/bash
# =============================================================================
# Cross-Harness Skill Learner & Sync
# =============================================================================
# 1. Runs the 4-stage extraction pipeline on all harness histories
# 2. Tracks feedback/decay for existing learned skills
# 3. Syncs learned skills to all harnesses (codex, pi, openclaw)
# 4. Optionally prunes decayed skills
#
# Usage:
#   ./sync-learned-skills.sh              # full extract + sync
#   ./sync-learned-skills.sh --dry-run    # preview only
#   ./sync-learned-skills.sh --verbose    # detailed output
#   ./sync-learned-skills.sh --stats      # show usage/decay stats
#   ./sync-learned-skills.sh --prune      # archive decayed skills
#   ./sync-learned-skills.sh --sync-only  # skip extraction, just sync
# =============================================================================

set -e

DRY_RUN=false
VERBOSE=false
STATS_ONLY=false
PRUNE=false
SYNC_ONLY=false
USE_LLM=true  # LLM distillation is now default
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACTOR="$SCRIPT_DIR/extract-conversation-skills.py"
LEARNED_DIR="$HOME/.claude/skills/learned"
LOG_FILE="$SCRIPT_DIR/shared-learning/sync.log"
LEARNING_MD="$SCRIPT_DIR/shared-learning/learning.md"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()     { echo -e "${BLUE}[LEARN]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
info()    { echo -e "${CYAN}[INFO]${NC} $1"; }

for arg in "$@"; do
    case $arg in
        --dry-run)   DRY_RUN=true ;;
        --verbose)   VERBOSE=true ;;
        --stats)     STATS_ONLY=true ;;
        --prune)     PRUNE=true ;;
        --sync-only) SYNC_ONLY=true ;;
        --no-llm)    USE_LLM=false ;;
    esac
done

mkdir -p "$SCRIPT_DIR/shared-learning"
mkdir -p "$LEARNED_DIR"

# Stats-only mode
if $STATS_ONLY; then
    python3 "$EXTRACTOR" --stats ${VERBOSE:+--verbose}
    exit 0
fi

# Prune mode
if $PRUNE; then
    log "Pruning decayed skills..."
    python3 "$EXTRACTOR" --prune ${DRY_RUN:+--dry-run} ${VERBOSE:+--verbose}
    exit 0
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Cross-Harness Skill Learner                            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
log "Started: $(date)"

# =============================================================================
# Step 1: Extract learned skills from all harness histories
# =============================================================================

if ! $SYNC_ONLY; then
    log "Step 1: Extracting patterns from conversation histories (4-stage pipeline)..."

    if [ ! -f "$EXTRACTOR" ]; then
        warn "Extractor not found: $EXTRACTOR"
        warn "Skipping extraction — will still sync existing learned skills"
    else
        EXTRACT_ARGS="--output $LEARNED_DIR"
        $VERBOSE && EXTRACT_ARGS="$EXTRACT_ARGS --verbose"
        $DRY_RUN && EXTRACT_ARGS="$EXTRACT_ARGS --dry-run"
        # Incremental extraction: only process new conversation files
        EXTRACT_ARGS="$EXTRACT_ARGS --incremental"

        # LLM distillation is now default; use --no-llm to disable
        if $USE_LLM; then
            EXTRACT_ARGS="$EXTRACT_ARGS --llm"
            log "LLM distillation enabled (default; use --no-llm to disable)"
        else
            log "LLM distillation disabled (--no-llm)"
        fi

        if python3 "$EXTRACTOR" $EXTRACT_ARGS; then
            success "Extraction complete"
        else
            warn "Extraction failed — see error output above"
        fi
    fi
else
    log "Step 1: Skipping extraction (--sync-only)"
fi

LEARNED_COUNT=$(ls "$LEARNED_DIR"/*.md 2>/dev/null | grep -v "/.usage" | wc -l | tr -d ' ')
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

    # Skip dotfiles and SKILL.md
    [[ "$skill_name" == .* ]] && return 0
    [[ "$skill_name" == "SKILL" ]] && return 0

    local dst_skill_dir="$dst_dir/$skill_name"

    if $DRY_RUN; then
        info "  [dry-run] Would sync: $skill_name → $harness"
        return 0
    fi

    if [ -f "$dst_skill_dir/SKILL.md" ] && \
       [ "$src_file" -ot "$dst_skill_dir/SKILL.md" ]; then
        $VERBOSE && info "  Up-to-date: $skill_name in $harness"
        return 0
    fi

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
PI_SKILLS_DIR="$HOME/.pi/agent/skills"
if [ -d "$HOME/.pi/agent" ]; then
    mkdir -p "$PI_SKILLS_DIR"
    for skill_file in "$LEARNED_DIR"/*.md; do
        [ -f "$skill_file" ] || continue
        sync_skill_to_harness "$skill_file" "$PI_SKILLS_DIR" "pi"
    done
    success "Pi: synced"
fi

# Sync to openclaw workspace skills
OPENCLAW_WS_SKILLS="$HOME/.openclaw/workspace/skills"
if [ -d "$HOME/.openclaw/workspace" ]; then
    mkdir -p "$OPENCLAW_WS_SKILLS"
    for skill_file in "$LEARNED_DIR"/*.md; do
        [ -f "$skill_file" ] || continue
        skill_name=$(basename "$skill_file" .md)
        [[ "$skill_name" == .* ]] && continue
        [[ "$skill_name" == "SKILL" ]] && continue
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

# Claude skills directory symlink
CLAUDE_SKILLS_LEARNED="$HOME/.claude/skills/learned"
if [ -d "$HOME/.claude/skills" ] && [ ! -d "$CLAUDE_SKILLS_LEARNED" ]; then
    ln -sfn "$LEARNED_DIR" "$CLAUDE_SKILLS_LEARNED" 2>/dev/null || true
fi

# =============================================================================
# Step 3: Update learning log
# =============================================================================

log "Step 3: Updating shared learning log..."
{
    echo ""
    echo "## Sync: $(date)"
    echo "- Learned skills total: $LEARNED_COUNT"
    echo "- Newly synced: $SYNCED"
    echo "- Harnesses updated: codex, pi, openclaw"
} >> "$LEARNING_MD" 2>/dev/null || true

echo "$(date) | learned=$LEARNED_COUNT synced=$SYNCED dry_run=$DRY_RUN" >> "$LOG_FILE" 2>/dev/null || true

echo ""
if $DRY_RUN; then
    warn "DRY RUN — no changes written"
else
    success "Sync complete: $SYNCED skills propagated across harnesses"
    success "Learned skills total: $LEARNED_COUNT"
fi
echo ""