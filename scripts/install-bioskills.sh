#!/bin/bash
# =============================================================================
# install-bioskills.sh — Install GPTomics/bioSkills into ai-skillweave
# =============================================================================
# Clones https://github.com/GPTomics/bioSkills and installs skills to
# ~/.claude/skills/ making them available on-demand via the Skill tool.
#
# Skills are NOT injected into every session — they load only when invoked.
# This prevents the 438 skills (multi-MB) from bloating every session's context.
#
# Usage:
#   scripts/install-bioskills.sh                    # Install all categories
#   scripts/install-bioskills.sh --categories "single-cell,variant-calling"
#   scripts/install-bioskills.sh --list             # Show available categories
#   scripts/install-bioskills.sh --update           # Re-pull latest from GitHub
#   scripts/install-bioskills.sh --dry-run          # Preview without installing
# =============================================================================
set -e

REPO_URL="https://github.com/GPTomics/bioSkills.git"
CACHE_DIR="$HOME/.claude/skills-cache/bioskills-src"
INSTALL_DIR="$HOME/.claude/skills"
DRY_RUN=false
LIST_ONLY=false
UPDATE=false
CATEGORIES=""

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()     { echo -e "${BLUE}[bioSkills]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
info()    { echo -e "${CYAN}[INFO]${NC} $1"; }

for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=true ;;
        --list)      LIST_ONLY=true ;;
        --update)    UPDATE=true ;;
        --categories=*) CATEGORIES="${arg#*=}" ;;
    esac
done

# =============================================================================
# Step 1: Fetch bioSkills source
# =============================================================================
mkdir -p "$HOME/.claude/skills-cache"

if [ -d "$CACHE_DIR/.git" ] && ! $UPDATE; then
    log "Using cached source at $CACHE_DIR (use --update to refresh)"
elif [ -d "$CACHE_DIR/.git" ] && $UPDATE; then
    log "Updating bioSkills source..."
    git -C "$CACHE_DIR" pull --quiet && success "Updated to latest"
else
    log "Cloning bioSkills from $REPO_URL ..."
    git clone --depth=1 --quiet "$REPO_URL" "$CACHE_DIR"
    success "Cloned bioSkills"
fi

# =============================================================================
# Step 2: Discover categories
# =============================================================================
AVAILABLE_CATS=()
while IFS= read -r -d '' dir; do
    cat_name=$(basename "$dir")
    # Only dirs with at least one */SKILL.md inside
    if ls "$dir"/*/SKILL.md >/dev/null 2>&1; then
        AVAILABLE_CATS+=("$cat_name")
    fi
done < <(find "$CACHE_DIR" -maxdepth 1 -mindepth 1 -type d -not -name ".*" -not -name "bioskills-installer" -print0 | sort -z)

if $LIST_ONLY; then
    echo ""
    echo "Available bioSkills categories (${#AVAILABLE_CATS[@]} total):"
    for cat in "${AVAILABLE_CATS[@]}"; do
        skill_count=$(ls "$CACHE_DIR/$cat"/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
        printf "  %-40s %s skills\n" "$cat" "$skill_count"
    done
    echo ""
    echo "Install all:    scripts/install-bioskills.sh"
    echo "Install some:   scripts/install-bioskills.sh --categories=\"single-cell,variant-calling\""
    exit 0
fi

# Resolve which categories to install
if [ -n "$CATEGORIES" ]; then
    IFS=',' read -ra INSTALL_CATS <<< "$CATEGORIES"
else
    INSTALL_CATS=("${AVAILABLE_CATS[@]}")
fi

# =============================================================================
# Step 3: Install skills
# =============================================================================
INSTALLED=0
SKIPPED=0

log "Installing ${#INSTALL_CATS[@]} categories to $INSTALL_DIR ..."

for cat in "${INSTALL_CATS[@]}"; do
    cat=$(echo "$cat" | xargs)  # trim whitespace
    src_dir="$CACHE_DIR/$cat"
    if [ ! -d "$src_dir" ]; then
        warn "Category not found: $cat (skipping)"
        continue
    fi

    dest_dir="$INSTALL_DIR/$cat"
    $DRY_RUN || mkdir -p "$dest_dir"

    for skill_dir in "$src_dir"/*/; do
        skill_name=$(basename "$skill_dir")
        skill_file="$skill_dir/SKILL.md"
        [ -f "$skill_file" ] || continue

        dest_skill_dir="$dest_dir/$skill_name"
        if $DRY_RUN; then
            info "  [dry-run] $cat/$skill_name"
        else
            mkdir -p "$dest_skill_dir"
            cp "$skill_file" "$dest_skill_dir/SKILL.md"
            # Copy usage-guide.md if present
            [ -f "$skill_dir/usage-guide.md" ] && cp "$skill_dir/usage-guide.md" "$dest_skill_dir/" || true
            INSTALLED=$((INSTALLED + 1))
        fi
    done
done

# =============================================================================
# Step 4: Register with superpowers skills manifest (if available)
# =============================================================================
SUPERPOWERS_DIR=$(find "$HOME/.claude/plugins/cache" -maxdepth 4 -name "superpowers" -type d 2>/dev/null | head -1)
if [ -n "$SUPERPOWERS_DIR" ] && ! $DRY_RUN; then
    # Create a thin wrapper skill per category in ~/.claude/skills/
    # so they show up as /bio-<category> commands
    for cat in "${INSTALL_CATS[@]}"; do
        cat=$(echo "$cat" | xargs)
        wrapper_dir="$INSTALL_DIR/bio-$cat"
        mkdir -p "$wrapper_dir"
        if [ ! -f "$wrapper_dir/SKILL.md" ]; then
            cat > "$wrapper_dir/SKILL.md" << EOF
---
name: bio-$cat
description: Bioinformatics skill set for $cat workflows. Trigger with specific task descriptions.
tool_type: bioinformatics
source: GPTomics/bioSkills
---

# Bio: $cat

Delegates to the appropriate skill in \`$INSTALL_DIR/$cat/\`.

## Available Skills
$(ls "$INSTALL_DIR/$cat/" 2>/dev/null | sed 's/^/- /' || echo "- (no skills installed)")

## Usage
Describe your specific $cat task and the appropriate sub-skill will be used.
EOF
        fi
    done
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
if $DRY_RUN; then
    warn "DRY RUN — nothing installed. Remove --dry-run to install."
else
    success "Installed $INSTALLED bioinformatics skills across ${#INSTALL_CATS[@]} categories"
    info "Skills are available on-demand via the Skill tool (NOT injected into every session)"
    info "Location: $INSTALL_DIR"
    echo ""
    info "To use: invoke a skill by name, e.g. 'Use the variant-calling/gatk-variant-calling skill'"
    info "Or:     list skills with --list"
fi
echo ""
