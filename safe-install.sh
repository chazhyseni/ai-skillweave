# =============================================================================
# SAFE Install - Everything Claude Code Skills
# =============================================================================
# Zero-RISK installation with automatic shell integration
# Installs ALL skills: ECC (1,789+) + Anthropic Official + Curated + your conversation-derived skills
# Works with: claude, openclaw, codex, ollama (direct or via ollama launch)
# Supports: .zshrc, .bashrc, .profile
# =============================================================================
set -e

CLAUDE_DIR="$HOME/.claude"
ECC_DIR="$HOME/.claude-everything-claude-code"
CURATED_DIR="$HOME/.claude-curated-skills"
SKILLS_CACHE_DIR="$HOME/.claude/skills-cache"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Parse arguments
WITH_CURATED=false
CURATED_ONLY=false

for arg in "$@"; do
    case $arg in
        --with-curated)
            WITH_CURATED=true
            shift
            ;;
        --curated-only)
            CURATED_ONLY=true
            WITH_CURATED=true
            shift
            ;;
        --uninstall)
            # Handled in main
            ;;
    esac
done

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   SAFE Install - Everything Claude Code Skills          ║"
if [ "$WITH_CURATED" = true ]; then
    echo "║   + Curated Skills (Anthropic Official + Community)      ║"
fi
echo "║   Zero-Risk • Auto Shell Integration                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# Step 1: Fetch everything-claude-code to isolated directory
# =============================================================================

install_ecc_skills() {
    if [ "$CURATED_ONLY" = true ]; then
        log "Skipping ECC skills (curated-only mode)..."
        return 0
    fi

    log "Step 1: Installing ECC skills..."

    if [ -d "$ECC_DIR" ]; then
        warn "Existing ECC installation found: $ECC_DIR"
        read -p "Overwrite? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            success "Keeping existing ECC installation"
            return 0
        else
            rm -rf "$ECC_DIR"
        fi
    fi

    mkdir -p "$ECC_DIR"
    cd /tmp
    if git clone --depth 1 https://github.com/affaan-m/everything-claude-code.git ecc-temp 2>/dev/null; then
        mv ecc-temp/* "$ECC_DIR/" 2>/dev/null || true
        rm -rf ecc-temp
        success "ECC skills installed: $ECC_DIR ($(find "$ECC_DIR/skills" -name '*.md' 2>/dev/null | wc -l | tr -d ' ') skills)"
    else
        error "Failed to fetch ECC repository"
        return 1
    fi

    # Copy your learned skills from conversation history
    mkdir -p "$ECC_DIR/skills/learned"
    if [ -d "$CLAUDE_DIR/skills/learned" ]; then
        cp -r "$CLAUDE_DIR/skills/learned"/* "$ECC_DIR/skills/learned/" 2>/dev/null || true
        success "Your conversation skills copied"
    fi
    if [ -d "$CLAUDE_DIR/skills/research" ]; then
        cp -r "$CLAUDE_DIR/skills/research"/* "$ECC_DIR/skills/research/" 2>/dev/null || true
    fi
}

# =============================================================================
# Step 2: Fetch curated skills (Anthropic Official + Community)
# =============================================================================

install_curated_skills() {
    if [ "$WITH_CURATED" = false ]; then
        log "Skipping curated skills (use --with-curated to add)"
        return 0
    fi

    log "Step 2: Installing curated skills..."

    # Remove existing curated installation
    if [ -d "$CURATED_DIR" ]; then
        rm -rf "$CURATED_DIR"
    fi
    mkdir -p "$CURATED_DIR"

    # 2a. Anthropic Official Skills
    log "Fetching Anthropic official skills..."
    mkdir -p "$CURATED_DIR/anthropic-official"
    cd /tmp
    if git clone --depth 1 https://github.com/anthropics/skills.git anthropic-temp 2>/dev/null; then
        mv anthropic-temp/* "$CURATED_DIR/anthropic-official/" 2>/dev/null || true
        rm -rf anthropic-temp
        ANTHROPIC_COUNT=$(find "$CURATED_DIR/anthropic-official" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
        success "Anthropic official skills: $ANTHROPIC_COUNT skills"
    else
        warn "Failed to fetch Anthropic skills (network issue?)"
    fi

    # 2b. Claude Skills Collection (community curated)
    log "Fetching community curated skills..."
    mkdir -p "$CURATED_DIR/community-curated"
    cd /tmp
    if git clone --depth 1 https://github.com/abubakarsiddik31/claude-skills-collection.git community-temp 2>/dev/null; then
        mv community-temp/* "$CURATED_DIR/community-curated/" 2>/dev/null || true
        rm -rf community-temp
        COMMUNITY_COUNT=$(find "$CURATED_DIR/community-curated" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
        success "Community curated skills: $COMMUNITY_COUNT skills"
    else
        warn "Failed to fetch community skills (network issue?)"
    fi

    # 2c. OpenAI Codex Official Skills (for Codex harness)
    log "Fetching OpenAI Codex official skills..."
    mkdir -p "$CURATED_DIR/openai-codex"
    cd /tmp
    if git clone --depth 1 https://github.com/openai/skills.git codex-temp 2>/dev/null; then
        mv codex-temp/* "$CURATED_DIR/openai-codex/" 2>/dev/null || true
        rm -rf codex-temp
        CODEX_COUNT=$(find "$CURATED_DIR/openai-codex" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
        success "OpenAI Codex skills: $CODEX_COUNT skills"
    else
        warn "Failed to fetch Codex skills (network issue?)"
    fi

    # Summary
    TOTAL_CURATED=$(find "$CURATED_DIR" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    success "Total curated skills: $TOTAL_CURATED"
}

# =============================================================================
# Step 2b: Create combined skills loader (single file with ALL skills)
# =============================================================================

create_loader() {
    log "Step 3: Creating skills loader (combining all skills)..."

    mkdir -p "$SKILLS_CACHE_DIR"

    # First, combine all skills into a single cached file
    COMBINED_FILE="$SKILLS_CACHE_DIR/combined-skills.txt"
    > "$COMBINED_FILE"  # Truncate/create file

    # Add learned skills first (your personal skills - always included)
    if [ -d "$CLAUDE_DIR/skills/learned" ]; then
        for skill in "$CLAUDE_DIR/skills/learned"/*.md; do
            if [ -f "$skill" ]; then
                echo "" >> "$COMBINED_FILE"
                sed '1,/^---$/d' "$skill" | sed '1,/^---$/d' >> "$COMBINED_FILE"
            fi
        done
    fi

    # Add curated skills with priority filtering
    # Priority 1: Anthropic Official (highest quality, vetted)
    if [ -d "$CURATED_DIR/anthropic-official" ]; then
        log "Merging Anthropic official skills (priority 1)..."
        find "$CURATED_DIR/anthropic-official" -name "*.md" -type f 2>/dev/null | while read -r skill; do
            echo "" >> "$COMBINED_FILE"
            sed '1,/^---$/d' "$skill" | sed '1,/^---$/d' >> "$COMBINED_FILE"
        done
    fi

    # Priority 2: OpenAI Codex skills (for Codex harness)
    if [ -d "$CURATED_DIR/openai-codex" ]; then
        log "Merging OpenAI Codex skills (priority 2, top 100)..."
        # Filter to most relevant skills (avoid duplicates, focus on core patterns)
        find "$CURATED_DIR/openai-codex" -name "*.md" -type f 2>/dev/null | head -100 | while read -r skill; do
            echo "" >> "$COMBINED_FILE"
            sed '1,/^---$/d' "$skill" | sed '1,/^---$/d' >> "$COMBINED_FILE"
        done
    fi

    # Priority 3: ECC skills (comprehensive base)
    if [ -d "$ECC_DIR/skills" ]; then
        log "Merging ECC skills (priority 3)..."
        find "$ECC_DIR/skills" -name "*.md" -type f ! -path "*/learned/*" 2>/dev/null | while read -r skill; do
            echo "" >> "$COMBINED_FILE"
            sed '1,/^---$/d' "$skill" | sed '1,/^---$/d' >> "$COMBINED_FILE"
        done
    fi

    # Priority 4: Community curated (only if space permits)
    if [ -d "$CURATED_DIR/community-curated" ]; then
        log "Merging community curated skills (priority 4, top 50)..."
        find "$CURATED_DIR/community-curated" -name "*.md" -type f 2>/dev/null | head -50 | while read -r skill; do
            echo "" >> "$COMBINED_FILE"
            sed '1,/^---$/d' "$skill" | sed '1,/^---$/d' >> "$COMBINED_FILE"
        done
    fi

    SKILL_COUNT=$(wc -l < "$COMBINED_FILE" | tr -d ' ')
    success "Combined skills cache created ($SKILL_COUNT lines)"

    # Create the loader script (for backwards compatibility, but don't export large vars)
    cat > "$SKILLS_CACHE_DIR/load-skills.sh" << LOADER
#!/bin/bash
# Load combined skills - file-based approach to avoid environment limits
# SKILLS_CONTENT available via: \$(cat ~/.claude/skills-cache/combined-skills.txt)
COMBINED_SKILLS_FILE='$COMBINED_FILE'
LOADER

    chmod +x "$SKILLS_CACHE_DIR/load-skills.sh"
    success "Loader created: $SKILLS_CACHE_DIR/load-skills.sh"
}

# =============================================================================
# Step 4: Add aliases to shell rc files (idempotent)
# =============================================================================

# Generate the skills block to add to shell rc
generate_skills_block() {
    cat << 'SKILLS_BLOCK'

# Skills Layer - SAFE Install (Everything Claude Code)
# All default commands now include skills (ECC + Anthropic Official + Curated + conversation-derived)
# To disable: run ~/.claude/scripts/safe-install.sh --uninstall

# Helper function to inject skills as system prompt (uses file to avoid arg length limits)
_claude_with_skills() {
    local _skills_file="/tmp/claude-skills-$$.txt"
    cat ~/.claude/skills-cache/combined-skills.txt > "$_skills_file" 2>/dev/null
    if [ -s "$_skills_file" ]; then
        (unset SKILLS_CONTENT CODEX_SYSTEM_PROMPT OPENCLAW_SYSTEM_PROMPT; command claude --append-system-prompt-file "$_skills_file" "$@")
    else
        (unset SKILLS_CONTENT CODEX_SYSTEM_PROMPT OPENCLAW_SYSTEM_PROMPT; command claude "$@")
    fi
    rm -f "$_skills_file"
}

_openclaw_with_skills() {
    # OpenClaw natively loads workspace/skills/ SKILL.md files — no extra env var needed.
    # OPENCLAW_SYSTEM_PROMPT_FILE is NOT a real openclaw env var (not in source).
    (unset SKILLS_CONTENT CODEX_SYSTEM_PROMPT OPENCLAW_SYSTEM_PROMPT; command openclaw "$@")
}

_codex_with_skills() {
    # Codex loads skills natively from ~/.codex/skills/ (ECC skills symlinked there)
    (unset SKILLS_CONTENT OPENCLAW_SYSTEM_PROMPT; command codex "$@")
}

_ollama_with_skills() {
    # OLLAMA_SYSTEM_FILE is NOT set (breaks ollama launch codex/pi).
    # OPENCLAW_SYSTEM_PROMPT_FILE is not a real openclaw env var — removed.
    # OpenClaw loads ECC skills natively from ~/.openclaw/workspace/skills/ SKILL.md files.
    (unset SKILLS_CONTENT CODEX_SYSTEM_PROMPT OPENCLAW_SYSTEM_PROMPT OLLAMA_SYSTEM_FILE; command ollama "$@")
}

_pi_with_skills() {
    # Pi loads skills natively from ~/.pi/agent/skills/ (ECC skills symlinked there)
    (unset SKILLS_CONTENT CODEX_SYSTEM_PROMPT OPENCLAW_SYSTEM_PROMPT; command pi "$@")
}

# Wrapper aliases
alias claude='_claude_with_skills'
alias openclaw='_openclaw_with_skills'
alias codex='_codex_with_skills'
alias ollama='_ollama_with_skills'
alias pi='_pi_with_skills'
# End Skills Layer
SKILLS_BLOCK
}

setup_shell_integration() {
    log "Step 4: Setting up shell integration..."

    # Find shell rc files to update
    local shell_rcs=()

    # Detect which shell rc files exist and should be updated
    if [ -f "$HOME/.zshrc" ]; then
        shell_rcs+=("$HOME/.zshrc")
        success "Found .zshrc"
    fi
    if [ -f "$HOME/.bashrc" ]; then
        shell_rcs+=("$HOME/.bashrc")
        success "Found .bashrc"
    fi
    if [ -f "$HOME/.profile" ] && [ ${#shell_rcs[@]} -eq 0 ]; then
        shell_rcs+=("$HOME/.profile")
        success "Found .profile"
    fi

    # If no rc files found, default to .zshrc (will be created)
    if [ ${#shell_rcs[@]} -eq 0 ]; then
        shell_rcs+=("$HOME/.zshrc")
        warn "No shell rc found, will create .zshrc"
    fi

    local skills_block
    skills_block=$(generate_skills_block)

    for shell_rc in "${shell_rcs[@]}"; do
        log "Processing $shell_rc..."

        # Check for existing entries
        if grep -q "# Skills Layer" "$shell_rc" 2>/dev/null; then
            warn "Shell integration already exists in $shell_rc"
            # Remove old entries first
            sed -i.bak '/# Skills Layer/,/# End Skills Layer/d' "$shell_rc" 2>/dev/null || true
            success "Removed old integration from $shell_rc"
        fi

        # Add new entries
        echo "$skills_block" >> "$shell_rc"
        success "Shell integration added to $shell_rc"
    done

    # Source the current shell's rc file
    if [ -n "$ZSH_VERSION" ]; then
        source "$HOME/.zshrc" 2>/dev/null || true
        success "Shell reloaded (.zshrc)"
    elif [ -n "$BASH_VERSION" ]; then
        source "$HOME/.bashrc" 2>/dev/null || true
        success "Shell reloaded (.bashrc)"
    else
        warn "Run 'source ~/.zshrc' or 'source ~/.bashrc' or restart terminal to activate"
    fi
}

# =============================================================================
# Step 4b: Symlink ECC skills into native skills dirs for codex and pi
# =============================================================================

link_native_skills() {
    log "Step 4b: Linking ECC skills into native harness skill directories..."

    if [ ! -d "$ECC_DIR/skills" ]; then
        warn "ECC skills not installed, skipping native linking"
        return 0
    fi

    # Codex: ~/.codex/skills/<skill-name>/ (each MUST have SKILL.md with simple frontmatter)
    # Codex's strict Rust YAML parser rejects:
    #   - Block scalars (description: >- or description: |)
    #   - Extra metadata fields beyond name/description/origin/tools
    if [ -d "$HOME/.codex/skills" ]; then
        local codex_count=0
        for dir in "$ECC_DIR/skills"/*/; do
            skill_name=$(basename "$dir")
            # Skip dirs without SKILL.md
            [ ! -f "$dir/SKILL.md" ] && continue
            # Skip block scalar descriptions (>-, >, |-, |) - break codex YAML parser
            grep -q '^description: *[>|]' "$dir/SKILL.md" 2>/dev/null && continue
            # Skip files with extra metadata fields (license, version, homepage, etc.)
            if grep -E '^[a-z_]+:' "$dir/SKILL.md" 2>/dev/null | grep -qvE '^(name|description|origin|tools):'; then
                continue
            fi
            if [ ! -e "$HOME/.codex/skills/$skill_name" ]; then
                ln -s "$dir" "$HOME/.codex/skills/$skill_name"
                codex_count=$((codex_count + 1))
            fi
        done
        success "Codex: $codex_count ECC skills linked ($(ls "$HOME/.codex/skills/" | wc -l | tr -d ' ') total)"
    else
        warn "~/.codex/skills not found — install Codex CLI first"
    fi

    # OpenClaw: ~/.openclaw/workspace/skills/<skill-name>/ (real copies, NOT symlinks)
    # Must be real files inside workspace root - OpenClaw rejects symlinks escaping the workspace
    # Skills appear with source="openclaw-workspace" and status="✓ ready"
    if [ -d "$HOME/.openclaw/workspace" ]; then
        local openclaw_count=0
        local ws_skills="$HOME/.openclaw/workspace/skills"
        mkdir -p "$ws_skills"
        for dir in "$ECC_DIR/skills"/*/; do
            skill_name=$(basename "$dir")
            [ ! -f "$dir/SKILL.md" ] && continue
            grep -q '^description: *[>|]' "$dir/SKILL.md" 2>/dev/null && continue
            if grep -E '^[a-z_]+:' "$dir/SKILL.md" 2>/dev/null | grep -qvE '^(name|description|origin|tools):'; then
                continue
            fi
            dst="$ws_skills/$skill_name"
            if [ ! -d "$dst" ]; then
                mkdir -p "$dst"
                cp "$dir/SKILL.md" "$dst/SKILL.md"
                openclaw_count=$((openclaw_count + 1))
            fi
        done
        success "OpenClaw: $openclaw_count ECC skills copied to workspace ($(ls "$ws_skills" | wc -l | tr -d ' ') total)"
    else
        warn "~/.openclaw/workspace not found — install openclaw first"
    fi

    # Pi: ~/.pi/agent/skills/<skill-name>/ (each MUST have SKILL.md)
    if [ -d "$HOME/.pi/agent" ]; then
        mkdir -p "$HOME/.pi/agent/skills"
        local pi_count=0
        for dir in "$ECC_DIR/skills"/*/; do
            skill_name=$(basename "$dir")
            # Skip dirs without SKILL.md - they break pi's skill scanner
            [ ! -f "$dir/SKILL.md" ] && continue
            if [ ! -e "$HOME/.pi/agent/skills/$skill_name" ]; then
                ln -s "$dir" "$HOME/.pi/agent/skills/$skill_name"
                pi_count=$((pi_count + 1))
            fi
        done
        success "Pi: $pi_count ECC skills linked ($(ls "$HOME/.pi/agent/skills/" | wc -l | tr -d ' ') total)"
    else
        warn "~/.pi/agent not found — install pi first"
    fi
}

# =============================================================================
# Step 5: Uninstall
# =============================================================================

uninstall() {
    log "Uninstalling skills layer..."

    # Remove shell integration from all possible rc files
    for rc_file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
        if [ -f "$rc_file" ]; then
            if grep -q "# Skills Layer" "$rc_file" 2>/dev/null; then
                sed -i.bak '/# Skills Layer/,/# End Skills Layer/d' "$rc_file" 2>/dev/null || true
                success "Removed shell integration from $rc_file"
            fi
        fi
    done

    # Remove installed files
    rm -rf "$ECC_DIR"
    rm -rf "$CURATED_DIR"
    rm -rf "$SKILLS_CACHE_DIR"

    success "Uninstall complete"
    echo ""
    echo "Note: Your original ~/.claude/ config was never modified."
    echo "Run 'source ~/.zshrc' or 'source ~/.bashrc' or restart terminal to fully clean up."
}

# =============================================================================
# Step 6: Show usage
# =============================================================================

show_usage() {
    # Count skills
    ECC_COUNT=0
    CURATED_COUNT=0
    if [ -d "$ECC_DIR/skills" ]; then
        ECC_COUNT=$(find "$ECC_DIR/skills" -name '*.md' ! -path '*/learned/*' 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ -d "$CURATED_DIR" ]; then
        CURATED_COUNT=$(find "$CURATED_DIR" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    fi
    TOTAL_COUNT=$((ECC_COUNT + CURATED_COUNT))

    cat << USAGE

╔══════════════════════════════════════════════════════════╗
║   Installation Complete                                  ║
╚══════════════════════════════════════════════════════════╝

Skills loaded:
  - ECC skills:           $ECC_COUNT
  - Curated skills:       $CURATED_COUNT (Anthropic Official + Community + Codex)
  - Total:                $TOTAL_COUNT

All default commands now have skills:
  claude                    ollama launch claude
  openclaw                  ollama launch openclaw
  codex                     ollama launch codex
  ollama

To bypass skills (raw commands):
  command claude [args]
  command codex [args]
  command openclaw [args]
  OLLAMA_SYSTEM="" ollama [args]

To list skills:
  ls ~/.claude-everything-claude-code/skills/   # ECC skills
  ls ~/.claude-curated-skills/                   # Curated skills
  ls ~/.claude/skills-cache/                     # Combined cache

To reinstall with curated skills:
  ~/.claude/scripts/safe-install.sh --with-curated

To uninstall:
  ~/.claude/scripts/safe-install.sh --uninstall

USAGE
}

# =============================================================================
# Main
# =============================================================================

if [[ "$*" == *"--uninstall"* ]]; then
    uninstall
    exit 0
fi

install_ecc_skills
install_curated_skills
create_loader
setup_shell_integration
link_native_skills
show_usage
