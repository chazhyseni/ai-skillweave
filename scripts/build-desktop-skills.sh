#!/bin/bash
# =============================================================================
# build-desktop-skills.sh — Install skills into Claude Desktop app
# =============================================================================
# Writes individual SKILL.md files directly into the Claude Desktop
# skills-plugin directory. Skills appear in the Desktop app's Skills panel.
#
# Cross-platform:
#   macOS:   ~/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/
#   Linux:   ~/.config/Claude/local-agent-mode-sessions/skills-plugin/  (expected)
#   Windows: %APPDATA%\Claude\local-agent-mode-sessions\skills-plugin\  (expected)
#
# Tiers:
#   essential  — Personal learned skills only
#   standard   — + All universal agents + top commands
#   full       — + ALL universal commands (default)
#
# Usage:
#   scripts/build-desktop-skills.sh                   # Full tier (default)
#   scripts/build-desktop-skills.sh --tier essential   # Minimal
#   scripts/build-desktop-skills.sh --tier standard    # Balanced
#   scripts/build-desktop-skills.sh --tier full        # Everything universal
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()     { echo -e "${BLUE}[SKILLS]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Skill source directories
LEARNED_DIR="$HOME/.claude/skills/learned"
AGENTS_DIR="$HOME/.claude-everything-claude-code/agents"
COMMANDS_DIR="$HOME/.claude-everything-claude-code/commands"

# Parse args
TIER="full"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tier) TIER="$2"; shift 2 ;;
        *) shift ;;
    esac
done

log "Tier: $TIER"

# =============================================================================
# Detect Desktop skills directory
# =============================================================================
detect_skills_dir() {
    local base=""
    case "$(uname -s)" in
        Darwin*)  base="$HOME/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin" ;;
        Linux*)   base="$HOME/.config/Claude/local-agent-mode-sessions/skills-plugin" ;;
        MINGW*|MSYS*|CYGWIN*)
            if [ -n "$APPDATA" ]; then
                base="$APPDATA/Claude/local-agent-mode-sessions/skills-plugin"
            else
                base="$HOME/AppData/Roaming/Claude/local-agent-mode-sessions/skills-plugin"
            fi
            ;;
    esac

    if [ ! -d "$base" ]; then
        warn "Skills-plugin directory not found: $base"
        warn "Open Claude Desktop at least once, then re-run."
        return 1
    fi

    # Find the most recent session with an org subdirectory
    local latest_session=""
    local latest_time=0
    for session_dir in "$base"/*/; do
        [ -d "$session_dir" ] || continue
        for org_dir in "$session_dir"*/; do
            [ -d "$org_dir/skills" ] || continue
            local mtime
            mtime=$(stat -f %m "$org_dir/skills" 2>/dev/null || stat -c %Y "$org_dir/skills" 2>/dev/null || echo 0)
            if [ "$mtime" -gt "$latest_time" ]; then
                latest_time=$mtime
                latest_session="$org_dir/skills"
            fi
        done
    done

    if [ -z "$latest_session" ]; then
        warn "No active skills session found in $base"
        return 1
    fi

    DESKTOP_SKILLS_DIR="$latest_session"
    log "Desktop skills dir: $DESKTOP_SKILLS_DIR"
}

detect_skills_dir || exit 1

# =============================================================================
# Skill lists by tier
# =============================================================================
UNIVERSAL_AGENTS=(
    performance-optimizer code-reviewer typescript-reviewer planner
    a11y-architect architect chief-of-staff security-reviewer
    database-reviewer e2e-runner build-error-resolver docs-lookup
    python-reviewer doc-updater tdd-guide refactor-cleaner
    seo-specialist code-explorer code-architect conversation-analyzer
    code-simplifier comment-analyzer silent-failure-hunter
    pr-test-analyzer harness-optimizer loop-operator type-design-analyzer
)

TOP_COMMANDS=(
    code-review tdd e2e build-fix feature-dev plan checkpoint
    review-pr refactor-clean test-coverage docs eval verify
    quality-gate context-budget model-route update-docs python-review
    prp-prd prp-plan prp-implement prp-pr prp-commit
)

ALL_UNIVERSAL_COMMANDS=(
    code-review tdd e2e build-fix feature-dev plan checkpoint review-pr
    refactor-clean test-coverage docs eval verify quality-gate context-budget
    model-route update-docs python-review prp-prd prp-plan prp-implement
    prp-pr prp-commit sessions save-session resume-session multi-execute
    multi-plan multi-workflow multi-frontend multi-backend santa-loop aside
    skill-create evolve skill-health orchestrate learn-eval pm2 jira
    instinct-import instinct-export instinct-status learn setup-pm promote
    hookify hookify-help hookify-configure hookify-list update-codemaps
    harness-audit loop-start loop-status projects devfleet prune
    prompt-optimize rules-distill agent-sort claw
)

# =============================================================================
# Install a single skill into Desktop
# =============================================================================
install_skill() {
    local name="$1"
    local source_file="$2"
    local skill_dir="$DESKTOP_SKILLS_DIR/$name"

    [ ! -f "$source_file" ] && return 1

    mkdir -p "$skill_dir"

    # Check if the source already has YAML frontmatter
    if head -1 "$source_file" | grep -q "^---"; then
        # Already has frontmatter — copy as-is
        cp "$source_file" "$skill_dir/SKILL.md"
    else
        # No frontmatter — wrap it with name + description from first line
        local desc
        desc=$(head -5 "$source_file" | grep -v "^#" | grep -v "^$" | head -1 | cut -c1-200 | sed 's/"/'"'"'/g')
        {
            echo "---"
            echo "name: $name"
            echo "description: \"$desc\""
            echo "---"
            echo ""
            cat "$source_file"
        } > "$skill_dir/SKILL.md"
    fi
    return 0
}

# =============================================================================
# Install skills by tier
# =============================================================================
LEARNED_COUNT=0
AGENT_COUNT=0
CMD_COUNT=0

# --- Personal learned skills (always) ---
if [ -d "$LEARNED_DIR" ]; then
    for f in "$LEARNED_DIR"/*.md; do
        [ -f "$f" ] || continue
        name=$(basename "$f" .md)
        if install_skill "learned-$name" "$f"; then
            LEARNED_COUNT=$((LEARNED_COUNT + 1))
        fi
    done
fi
log "Installed $LEARNED_COUNT personal learned skills"

# --- Universal agents (standard + full) ---
if [ "$TIER" = "standard" ] || [ "$TIER" = "full" ]; then
    for name in "${UNIVERSAL_AGENTS[@]}"; do
        f="$AGENTS_DIR/$name.md"
        if install_skill "agent-$name" "$f"; then
            AGENT_COUNT=$((AGENT_COUNT + 1))
        fi
    done
    log "Installed $AGENT_COUNT agent skills"
fi

# --- Commands (standard: top 23, full: all) ---
if [ "$TIER" = "standard" ]; then
    for name in "${TOP_COMMANDS[@]}"; do
        f="$COMMANDS_DIR/$name.md"
        if install_skill "cmd-$name" "$f"; then
            CMD_COUNT=$((CMD_COUNT + 1))
        fi
    done
elif [ "$TIER" = "full" ]; then
    SEEN_FILE=$(mktemp)
    trap "rm -f $SEEN_FILE" EXIT
    for name in "${ALL_UNIVERSAL_COMMANDS[@]}"; do
        if ! grep -qx "$name" "$SEEN_FILE" 2>/dev/null; then
            echo "$name" >> "$SEEN_FILE"
            f="$COMMANDS_DIR/$name.md"
            if install_skill "cmd-$name" "$f"; then
                CMD_COUNT=$((CMD_COUNT + 1))
            fi
        fi
    done
    rm -f "$SEEN_FILE"
fi
log "Installed $CMD_COUNT command skills"

TOTAL=$((LEARNED_COUNT + AGENT_COUNT + CMD_COUNT))
success "Installed $TOTAL skills into Claude Desktop (tier: $TIER)"
success "Path: $DESKTOP_SKILLS_DIR"
echo ""
log "Restart Claude Desktop to load new skills."
