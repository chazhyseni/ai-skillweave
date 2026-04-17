# =============================================================================
# SAFE Install - Everything Claude Code Skills
# =============================================================================
# Zero-RISK installation with automatic shell integration
# Installs ALL skills: ECC + Anthropic Official + Curated + your conversation-derived skills
# Works with: claude, openclaw, codex, ollama (direct or via ollama launch)
# Supports: .zshrc, .bashrc, .profile
# Platforms: macOS, Linux, Windows (WSL/MSYS2/Cygwin)
# =============================================================================
set -e

CLAUDE_DIR="$HOME/.claude"
ECC_DIR="$HOME/.claude-everything-claude-code"
CURATED_DIR="$HOME/.claude-curated-skills"
SCIENCE_DIR="$HOME/.claude-scientific-skills"
SKILLS_CACHE_DIR="$HOME/.claude/skills-cache"

# Platform detection
case "$(uname -s)" in
    Darwin*)                 OS_TYPE="macOS" ;;
    Linux*)                  OS_TYPE="Linux" ;;
    MINGW*|MSYS*|CYGWIN*)   OS_TYPE="Windows" ;;
    *)                       OS_TYPE="Unknown" ;;
esac

# Detect user's default shell (not the shell running this script)
_detect_user_shell() {
    local shell_name="${SHELL##*/}"
    case "$shell_name" in
        zsh)  echo "zsh" ;;
        bash) echo "bash" ;;
        fish) echo "fish" ;;
        *)    echo "bash" ;;  # safe default
    esac
}
USER_SHELL="$(_detect_user_shell)"

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
WITH_SCIENCE=false

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
        --with-science)
            WITH_SCIENCE=true
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
if [ "$WITH_SCIENCE" = true ]; then
    echo "║   + Scientific Skills (K-Dense Agent Skills)            ║"
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
        # If stdin is a terminal, prompt interactively; otherwise keep existing
        if [ -t 0 ]; then
            read -p "Overwrite? [y/N] " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                success "Keeping existing ECC installation"
                return 0
            else
                rm -rf "$ECC_DIR"
            fi
        else
            success "Non-interactive mode — keeping existing ECC installation"
            return 0
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
# Step 2b: Install K-Dense Scientific Agent Skills
# =============================================================================

install_science_skills() {
    if [ "$WITH_SCIENCE" = false ]; then
        log "Skipping scientific skills (use --with-science to add)"
        return 0
    fi

    log "Step 2b: Installing K-Dense Scientific Agent Skills..."

    if [ -d "$SCIENCE_DIR" ]; then
        warn "Existing scientific skills found: $SCIENCE_DIR"
        if [ -t 0 ]; then
            read -p "Overwrite? [y/N] " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                success "Keeping existing scientific skills"
                return 0
            else
                rm -rf "$SCIENCE_DIR"
            fi
        else
            success "Non-interactive mode — keeping existing scientific skills"
            return 0
        fi
    fi

    mkdir -p "$SCIENCE_DIR"
    cd /tmp
    if git clone --depth 1 https://github.com/K-Dense-AI/scientific-agent-skills.git science-temp 2>/dev/null; then
        # Copy skill directories (each contains SKILL.md + optional references/scripts/assets)
        mkdir -p "$SCIENCE_DIR/scientific-skills"
        cp -r science-temp/scientific-skills/* "$SCIENCE_DIR/scientific-skills/" 2>/dev/null || true
        SCIENCE_COUNT=$(find "$SCIENCE_DIR/scientific-skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
        rm -rf science-temp
        success "K-Dense scientific skills installed: $SCIENCE_DIR ($SCIENCE_COUNT skills)"
    else
        error "Failed to fetch K-Dense scientific-agent-skills repository"
        return 1
    fi
}

# =============================================================================
# Step 3: Create combined skills loader (single file with ALL skills)
# =============================================================================

create_loader() {
    log "Step 3: Creating skills loader (combining all skills)..."

    mkdir -p "$SKILLS_CACHE_DIR"

    # First, combine all skills into a single cached file
    COMBINED_FILE="$SKILLS_CACHE_DIR/combined-skills.txt"
    > "$COMBINED_FILE"  # Truncate/create file

    # Preamble: conciseness + MCP usage rules (injected at top of system prompt)
    cat >> "$COMBINED_FILE" << 'PREAMBLE'
# CRITICAL INSTRUCTIONS — READ FIRST

## Conciseness
- Be terse. No trailing summaries, status tables, or "here's what I did" recaps.
- Show the change, not paragraphs explaining the change.

## Use MCP tools PROACTIVELY
- Use codesight_get_summary BEFORE exploring a codebase with Grep/Glob/Read.
- Use smart_read (token-optimizer) instead of Read for large files.
- Use context7 query-docs BEFORE answering library/framework questions from training data.
- Use exa-web-search for anything that may have changed since training cutoff.

PREAMBLE

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

    # Priority 5: K-Dense Scientific Agent Skills (SKILL.md in subdirectories)
    if [ -d "$SCIENCE_DIR/scientific-skills" ]; then
        log "Merging K-Dense scientific skills (priority 5)..."
        find "$SCIENCE_DIR/scientific-skills" -name "SKILL.md" -type f 2>/dev/null | while read -r skill; do
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
    # Lean cache: personal learned skills only (injected into Anthropic Opus sessions)
    if ls "$CLAUDE_DIR/skills/learned"/*.md >/dev/null 2>&1; then
        cat "$CLAUDE_DIR/skills/learned"/*.md > "$SKILLS_CACHE_DIR/lean-skills.txt"
        success "Lean cache created: $SKILLS_CACHE_DIR/lean-skills.txt (personal skills only — 98% fewer tokens)"
    else
        > "$SKILLS_CACHE_DIR/lean-skills.txt"
        warn "No learned skills found — lean cache is empty"
    fi
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
    log "Detected user shell: $USER_SHELL (platform: $OS_TYPE)"

    # Find shell rc files to update
    local shell_rcs=()

    # Detect which shell rc files exist and should be updated.
    # Add ALL existing rc files so the user can switch shells without losing integration.
    if [ -f "$HOME/.zshrc" ]; then
        shell_rcs+=("$HOME/.zshrc")
        success "Found .zshrc"
    fi
    if [ -f "$HOME/.bashrc" ]; then
        shell_rcs+=("$HOME/.bashrc")
        success "Found .bashrc"
    fi
    if [ -f "$HOME/.bash_profile" ] && [ ${#shell_rcs[@]} -eq 0 ]; then
        # .bash_profile is used on macOS instead of .bashrc for login shells
        shell_rcs+=("$HOME/.bash_profile")
        success "Found .bash_profile"
    fi
    if [ -f "$HOME/.profile" ] && [ ${#shell_rcs[@]} -eq 0 ]; then
        shell_rcs+=("$HOME/.profile")
        success "Found .profile"
    fi

    # If no rc files found, create the appropriate one for the user's actual shell
    if [ ${#shell_rcs[@]} -eq 0 ]; then
        local default_rc
        case "$USER_SHELL" in
            zsh)  default_rc="$HOME/.zshrc" ;;
            bash) default_rc="$HOME/.bashrc" ;;
            *)    default_rc="$HOME/.bashrc" ;;
        esac
        shell_rcs+=("$default_rc")
        warn "No shell rc found, will create $(basename "$default_rc")"
    fi

    local skills_block
    skills_block=$(generate_skills_block)

    for shell_rc in "${shell_rcs[@]}"; do
        log "Processing $shell_rc..."

        # Check for existing entries and remove old block first (idempotent)
        if grep -q "# Skills Layer" "$shell_rc" 2>/dev/null; then
            warn "Shell integration already exists in $shell_rc — replacing"
            # sed -i with backup suffix works on both GNU (Linux) and BSD (macOS) sed
            sed -i.bak '/# Skills Layer/,/# End Skills Layer/d' "$shell_rc" 2>/dev/null || true
            success "Removed old integration from $shell_rc"
        fi

        # Add new entries
        echo "$skills_block" >> "$shell_rc"
        success "Shell integration added to $shell_rc"
    done

    # Determine which rc to tell the user to source
    local primary_rc
    case "$USER_SHELL" in
        zsh)  primary_rc="$HOME/.zshrc" ;;
        bash) primary_rc="$HOME/.bashrc" ;;
        *)    primary_rc="${shell_rcs[0]}" ;;
    esac

    # Source the current shell's rc file (may fail in non-interactive subshell — that's OK)
    if [ -n "$ZSH_VERSION" ]; then
        source "$HOME/.zshrc" 2>/dev/null || true
        success "Shell reloaded (.zshrc)"
    elif [ -n "$BASH_VERSION" ]; then
        source "$HOME/.bashrc" 2>/dev/null || true
        success "Shell reloaded (.bashrc)"
    else
        warn "Run 'source $(basename "$primary_rc")' or restart terminal to activate"
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

    # Claude Code: ~/.claude/skills/<skill-name>.md (flat markdown files)
    # This is what Claude Code's /skills command reads. Skills placed here work
    # regardless of launch method (direct, ollama launch, VSCode extension).
    local claude_skills_dir="$HOME/.claude/skills"
    mkdir -p "$claude_skills_dir"
    local claude_count=0
    for dir in "$ECC_DIR/skills"/*/; do
        skill_name=$(basename "$dir")
        # Use SKILL.md if it exists, otherwise find any .md
        local src_file=""
        if [ -f "$dir/SKILL.md" ]; then
            src_file="$dir/SKILL.md"
        else
            src_file=$(find "$dir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | head -1)
        fi
        [ -z "$src_file" ] && continue
        local dst="$claude_skills_dir/${skill_name}.md"
        if [ ! -f "$dst" ]; then
            cp "$src_file" "$dst"
            claude_count=$((claude_count + 1))
        fi
    done
    success "Claude Code: $claude_count ECC skills installed to ~/.claude/skills/ ($(ls "$claude_skills_dir"/*.md 2>/dev/null | wc -l | tr -d ' ') total)"

    # Codex: handled by update-ecc.sh which properly sanitizes YAML (symlinks
    # for clean skills, sanitized copies for skills with block scalars/extra fields).
    # safe-install.sh used to skip invalid skills entirely — update-ecc.sh fixes them.
    if [ -d "$HOME/.codex/skills" ]; then
        log "Codex skills will be synced by update-ecc.sh (proper YAML sanitization)"
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

    # K-Dense Scientific Skills: install into Claude Code native skills dir
    # These are directory-based skills (SKILL.md + references/ + scripts/ + assets/)
    # Claude Code supports both flat .md files and directory-based skills
    if [ -d "$SCIENCE_DIR/scientific-skills" ]; then
        local science_count=0
        for dir in "$SCIENCE_DIR/scientific-skills"/*/; do
            skill_name=$(basename "$dir")
            [ ! -f "$dir/SKILL.md" ] && continue
            # Claude Code: flat .md file (SKILL.md content)
            local dst="$claude_skills_dir/${skill_name}.md"
            if [ ! -f "$dst" ]; then
                cp "$dir/SKILL.md" "$dst"
                science_count=$((science_count + 1))
            fi
        done
        success "Claude Code: $science_count K-Dense scientific skills installed to ~/.claude/skills/"

        # OpenClaw: real copies for K-Dense skills (sanitize YAML)
        if [ -d "$HOME/.openclaw/workspace" ]; then
            local oc_science_count=0
            for dir in "$SCIENCE_DIR/scientific-skills"/*/; do
                skill_name=$(basename "$dir")
                [ ! -f "$dir/SKILL.md" ] && continue
                dst="$ws_skills/$skill_name"
                if [ ! -d "$dst" ]; then
                    mkdir -p "$dst"
                    # Copy SKILL.md (sanitize if needed)
                    if grep -q '^description: *[>|]' "$dir/SKILL.md" 2>/dev/null || \
                       grep -E '^[a-z_]+:' "$dir/SKILL.md" 2>/dev/null | grep -qvE '^(name|description|origin|tools|license|allowed-tools|metadata|compatibility):'; then
                        # Needs sanitization — copy only SKILL.md with sanitized content
                        python3 -c "
import re, sys
with open('$dir/SKILL.md') as f:
    content = f.read()
parts = content.split('---', 2)
if len(parts) >= 3:
    print('---' + parts[1] + '---' + parts[2])
else:
    print(content)
" > "$dst/SKILL.md" 2>/dev/null || cp "$dir/SKILL.md" "$dst/SKILL.md"
                    else
                        cp "$dir/SKILL.md" "$dst/SKILL.md"
                    fi
                    # Copy references/ and scripts/ and assets/ if they exist
                    cp -r "$dir/references" "$dst/" 2>/dev/null || true
                    cp -r "$dir/scripts" "$dst/" 2>/dev/null || true
                    cp -r "$dir/assets" "$dst/" 2>/dev/null || true
                    oc_science_count=$((oc_science_count + 1))
                fi
            done
            success "OpenClaw: $oc_science_count K-Dense scientific skills copied to workspace"
        fi

        # Pi: symlink K-Dense skills
        if [ -d "$HOME/.pi/agent" ]; then
            local pi_science_count=0
            for dir in "$SCIENCE_DIR/scientific-skills"/*/; do
                skill_name=$(basename "$dir")
                [ ! -f "$dir/SKILL.md" ] && continue
                if [ ! -e "$HOME/.pi/agent/skills/$skill_name" ]; then
                    ln -s "$dir" "$HOME/.pi/agent/skills/$skill_name"
                    pi_science_count=$((pi_science_count + 1))
                fi
            done
            success "Pi: $pi_science_count K-Dense scientific skills linked"
        fi

        # Codex: handled by update-ecc.sh which properly sanitizes YAML
        if [ -d "$HOME/.codex/skills" ]; then
            log "Codex K-Dense skills will be synced by update-ecc.sh (proper YAML sanitization)"
        fi
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
    rm -rf "$SCIENCE_DIR"
    rm -rf "$SKILLS_CACHE_DIR"
    # Remove Claude Code native skills (only ECC-originated ones)
    if [ -d "$HOME/.claude/skills" ]; then
        rm -rf "$HOME/.claude/skills"
        success "Removed ~/.claude/skills/"
    fi

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
    SCIENCE_COUNT=0
    if [ -d "$ECC_DIR/skills" ]; then
        ECC_COUNT=$(find "$ECC_DIR/skills" -name '*.md' ! -path '*/learned/*' 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ -d "$CURATED_DIR" ]; then
        CURATED_COUNT=$(find "$CURATED_DIR" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ -d "$SCIENCE_DIR/scientific-skills" ]; then
        SCIENCE_COUNT=$(find "$SCIENCE_DIR/scientific-skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
    fi
    TOTAL_COUNT=$((ECC_COUNT + CURATED_COUNT + SCIENCE_COUNT))

    # Determine which rc file to tell the user to source
    local reload_rc
    case "$USER_SHELL" in
        zsh)  reload_rc="~/.zshrc" ;;
        bash) reload_rc="~/.bashrc" ;;
        *)    reload_rc="~/.bashrc" ;;
    esac

    cat << USAGE

╔══════════════════════════════════════════════════════════╗
║   Installation Complete ($OS_TYPE / $USER_SHELL)
╚══════════════════════════════════════════════════════════╝

Skills loaded:
  - ECC skills:           $ECC_COUNT
  - Curated skills:       $CURATED_COUNT (Anthropic Official + Community + Codex)
  - Scientific skills:    $SCIENCE_COUNT (K-Dense Agent Skills)
  - Total:                $TOTAL_COUNT

Activate:  source $reload_rc   (or restart terminal)

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
  ls ~/.claude-scientific-skills/scientific-skills/  # K-Dense scientific skills
  ls ~/.claude/skills-cache/                     # Combined cache

To reinstall with curated + scientific skills:
  ~/.claude/scripts/safe-install.sh --with-curated --with-science

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
install_science_skills
create_loader
setup_shell_integration
link_native_skills
show_usage
