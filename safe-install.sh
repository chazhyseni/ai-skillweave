# =============================================================================
# SAFE Install - Everything Claude Code Skills
# =============================================================================
# Zero-RISK installation with automatic shell integration
# Installs ALL skills: ECC + Anthropic Official + Curated + your conversation-derived skills
# Works with: claude, openclaw, codex, pi, copilot, ollama (direct or via ollama launch)
# Supports: .zshrc, .bashrc, .profile
# Platforms: macOS, Linux, Windows (WSL/MSYS2/Cygwin)
# =============================================================================
set -e

CLAUDE_DIR="$HOME/.claude"
ECC_DIR="$HOME/.claude-everything-claude-code"
CURATED_DIR="$HOME/.claude-curated-skills"
SCIENCE_DIR="$HOME/.claude-scientific-skills"
CLAWBIO_DIR="$HOME/.claude-clawbio-skills"
SKILLS_CACHE_DIR="$HOME/.claude/skills-cache"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Platform detection
case "$(uname -s)" in
    Darwin*)                 OS_TYPE="macOS" ;;
    Linux*)                  OS_TYPE="Linux" ;;
    MINGW*|MSYS*|CYGWIN*)   OS_TYPE="Windows" ;;  # untested; use WSL
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
WITH_SCIENCE=true
WITH_BIO=true
WITH_LEARN=true

for arg in "$@"; do
    case $arg in
        --with-curated)
            WITH_CURATED=true
            ;;
        --curated-only)
            CURATED_ONLY=true
            WITH_CURATED=true
            ;;
        --with-science)
            WITH_SCIENCE=true
            ;;
        --without-science)
            WITH_SCIENCE=false
            ;;
        --with-bio)
            WITH_BIO=true
            ;;
        --without-bio)
            WITH_BIO=false
            ;;
        --no-learn)
            WITH_LEARN=false
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
    echo "║   + Curated Skills (Anthropic Official + Codex)          ║"
fi
if [ "$WITH_SCIENCE" = true ]; then
    echo "║   + Scientific Skills (K-Dense Agent Skills)            ║"
fi
if [ "$WITH_BIO" = true ]; then
    echo "║   + Bioinformatics Skills (ClawBio)                    ║"
fi
echo "║   Zero-Risk • Auto Shell Integration                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# Bootstrap prerequisites (lightweight — install.sh does the heavy lifting)
# =============================================================================
if ! command -v git >/dev/null 2>&1; then
    log "git not found — attempting install..."
    if [ "$OS_TYPE" = "macOS" ] && command -v brew >/dev/null 2>&1; then
        brew install git 2>/dev/null || warn "brew install git failed"
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq git 2>/dev/null || warn "apt install git failed"
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y git 2>/dev/null || warn "dnf install git failed"
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm git 2>/dev/null || warn "pacman install git failed"
    fi
fi
command -v git >/dev/null 2>&1 || error "git is required but could not be installed"

if ! command -v python3 >/dev/null 2>&1; then
    log "python3 not found — attempting install..."
    if [ "$OS_TYPE" = "macOS" ] && command -v brew >/dev/null 2>&1; then
        brew install python3 2>/dev/null || warn "brew install python3 failed"
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq python3 python3-pip 2>/dev/null || warn "apt install python3 failed"
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y python3 python3-pip 2>/dev/null || warn "dnf install python3 failed"
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm python python-pip 2>/dev/null || warn "pacman install python failed"
    fi
fi
command -v python3 >/dev/null 2>&1 || error "python3 is required but could not be installed"

# Pre-install Python dependencies for auto-learning pipeline
log "Installing Python dependencies for skill extraction..."
_install_python_deps() {
    local pkgs="sentence-transformers>=3.0.0 scikit-learn>=1.5.0"
    local in_venv=""
    if python3 -c "import sys; sys.exit(0 if (sys.prefix != sys.base_prefix) else 1)" 2>/dev/null; then
        in_venv=1
    fi
    if [ -n "$in_venv" ]; then
        log "Detected Python virtualenv — skipping --user flag"
        if python3 -m pip install --quiet $pkgs 2>&1; then
            success "Python deps installed (venv)"
            return 0
        fi
    else
        if python3 -m pip install --user --quiet $pkgs 2>&1; then
            success "Python deps installed (user site)"
            return 0
        fi
        warn "pip --user failed — trying without --user..."
        if python3 -m pip install --quiet $pkgs 2>&1; then
            success "Python deps installed (system site)"
            return 0
        fi
    fi
    if command -v pip3 >/dev/null 2>&1 && pip3 install --quiet $pkgs 2>&1; then
        success "Python deps installed via pip3"
        return 0
    fi
    warn "All pip install attempts failed (see errors above)"
    warn "Try manually: python3 -m pip install sentence-transformers scikit-learn"
    return 1
}
_install_python_deps || warn "Python deps missing — the learning pipeline will fail until fixed"

# Ensure node/npm available for harness installs
if ! command -v npm >/dev/null 2>&1; then
    log "npm not found — attempting install..."
    if [ "$OS_TYPE" = "macOS" ] && command -v brew >/dev/null 2>&1; then
        brew install node 2>/dev/null || warn "brew install node failed"
    elif command -v apt-get >/dev/null 2>&1; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash - 2>/dev/null && \
            apt-get install -y nodejs 2>/dev/null || warn "NodeSource install failed"
    fi
fi

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
# Step 2: Fetch curated skills (Anthropic Official + Codex)
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
# Step 2c: Install ClawBio Bioinformatics Skills
# =============================================================================

install_bio_skills() {
    if [ "$WITH_BIO" = false ]; then
        log "Skipping ClawBio bioinformatics skills (use --with-bio to add)"
        return 0
    fi

    log "Step 2c: Installing ClawBio Bioinformatics Skills..."

    if [ -d "$CLAWBIO_DIR" ]; then
        warn "Existing ClawBio skills found: $CLAWBIO_DIR"
        if [ -t 0 ]; then
            read -p "Overwrite? [y/N] " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                success "Keeping existing ClawBio skills"
                return 0
            else
                rm -rf "$CLAWBIO_DIR"
            fi
        else
            success "Non-interactive mode — keeping existing ClawBio skills"
            return 0
        fi
    fi

    mkdir -p "$CLAWBIO_DIR"
    cd /tmp
    if git clone --depth 1 https://github.com/ClawBio/ClawBio.git clawbio-temp 2>/dev/null; then
        # Copy skill directories (each contains SKILL.md + optional Python scripts/examples/tests)
        mkdir -p "$CLAWBIO_DIR/skills"
        cp -r clawbio-temp/skills/* "$CLAWBIO_DIR/skills/" 2>/dev/null || true
        BIO_COUNT=$(find "$CLAWBIO_DIR/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
        rm -rf clawbio-temp
        success "ClawBio bioinformatics skills installed: $CLAWBIO_DIR ($BIO_COUNT skills)"
    else
        error "Failed to fetch ClawBio repository"
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
                awk 'BEGIN{f=0} /^---$/{f++; next} f>=2' "$skill" >> "$COMBINED_FILE"
            fi
        done
    fi

    # Add curated skills with priority filtering
    # Priority 1: Anthropic Official (highest quality, vetted)
    if [ -d "$CURATED_DIR/anthropic-official" ]; then
        log "Merging Anthropic official skills (priority 1)..."
        find "$CURATED_DIR/anthropic-official" -name "*.md" -type f 2>/dev/null | while read -r skill; do
            echo "" >> "$COMBINED_FILE"
            awk 'BEGIN{f=0} /^---$/{f++; next} f>=2' "$skill" >> "$COMBINED_FILE"
        done
    fi

    # Priority 2: OpenAI Codex skills (for Codex harness)
    if [ -d "$CURATED_DIR/openai-codex" ]; then
        log "Merging OpenAI Codex skills (priority 2, top 100)..."
        # Filter to most relevant skills (avoid duplicates, focus on core patterns)
        find "$CURATED_DIR/openai-codex" -name "*.md" -type f 2>/dev/null | head -100 | while read -r skill; do
            echo "" >> "$COMBINED_FILE"
            awk 'BEGIN{f=0} /^---$/{f++; next} f>=2' "$skill" >> "$COMBINED_FILE"
        done
    fi

    # Priority 3: ECC skills (comprehensive base)
    if [ -d "$ECC_DIR/skills" ]; then
        log "Merging ECC skills (priority 3)..."
        find "$ECC_DIR/skills" -name "*.md" -type f ! -path "*/learned/*" 2>/dev/null | while read -r skill; do
            echo "" >> "$COMBINED_FILE"
            awk 'BEGIN{f=0} /^---$/{f++; next} f>=2' "$skill" >> "$COMBINED_FILE"
        done
    fi

    # Priority 4: K-Dense Scientific Agent Skills (SKILL.md in subdirectories)
    if [ -d "$SCIENCE_DIR/scientific-skills" ]; then
        log "Merging K-Dense scientific skills (priority 4)..."
        find "$SCIENCE_DIR/scientific-skills" -name "SKILL.md" -type f 2>/dev/null | while read -r skill; do
            echo "" >> "$COMBINED_FILE"
            awk 'BEGIN{f=0} /^---$/{f++; next} f>=2' "$skill" >> "$COMBINED_FILE"
        done
    fi

    # Priority 6: ClawBio Bioinformatics Skills (SKILL.md in subdirectories)
    if [ -d "$CLAWBIO_DIR/skills" ]; then
        log "Merging ClawBio bioinformatics skills (priority 6)..."
        find "$CLAWBIO_DIR/skills" -name "SKILL.md" -type f 2>/dev/null | while read -r skill; do
            echo "" >> "$COMBINED_FILE"
            awk 'BEGIN{f=0} /^---$/{f++; next} f>=2' "$skill" >> "$COMBINED_FILE"
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
# Uses lean-skills.txt (personal learned skills only, ~1-2K tokens) instead of
# combined-skills.txt (~1.4M tokens — exceeds Claude's 200K context window).
# The full 450+ skill library loads natively via ~/.claude/skills/ (/skills command).
_claude_with_skills() {
    local _skills_file="/tmp/claude-skills-$$.txt"
    cat ~/.claude/skills-cache/lean-skills.txt > "$_skills_file" 2>/dev/null
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

_copilot_with_skills() {
    # Copilot CLI natively discovers SKILL.md files from ~/.claude/skills/ as "personal-claude"
    # source — no prompt injection needed. It also reads .github/skills, .agents/skills,
    # ~/.copilot/config/skills, ~/.agents/skills. Use COPILOT_SKILLS_DIRS to add extra dirs.
    # This wrapper is a passthrough for env cleanup only.
    (unset SKILLS_CONTENT CODEX_SYSTEM_PROMPT OPENCLAW_SYSTEM_PROMPT; command copilot "$@")
}

# Wrapper aliases
alias claude='_claude_with_skills'
alias openclaw='_openclaw_with_skills'
alias codex='_codex_with_skills'
alias ollama='_ollama_with_skills'
alias pi='_pi_with_skills'
alias copilot='_copilot_with_skills'

# Learning pipeline commands
alias learn-sync='bash ~/.claude/scripts/sync-learned-skills.sh'
alias learn-sync-dry='bash ~/.claude/scripts/sync-learned-skills.sh --dry-run'
alias learn-stats='bash ~/.claude/scripts/sync-learned-skills.sh --stats'
alias learn-prune='bash ~/.claude/scripts/sync-learned-skills.sh --prune'
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
    # Use subshell to prevent set -e from catching failures inside sourced rc
    if [ -n "$ZSH_VERSION" ]; then
        (source "$HOME/.zshrc" 2>/dev/null) || true
        success "Shell reloaded (.zshrc)"
    elif [ -n "$BASH_VERSION" ]; then
        (source "$HOME/.bashrc" 2>/dev/null) || true
        success "Shell reloaded (.bashrc)"
    else
        warn "Run 'source $(basename "$primary_rc")' or restart terminal to activate"
    fi
}

# =============================================================================
# Step 4b: Copy learning pipeline scripts to ~/.claude/scripts/
# =============================================================================
# The generated shell aliases (learn-sync, learn-stats, etc.) reference
# ~/.claude/scripts/sync-learned-skills.sh. This step ensures those files exist.

copy_scripts_to_claude_dir() {
    local scripts_dest="$HOME/.claude/scripts"
    mkdir -p "$scripts_dest"

    local scripts_to_copy=(
        "sync-learned-skills.sh"
        "extract-conversation-skills.py"
        "safe-install.sh"
    )
    local copied=0
    for script in "${scripts_to_copy[@]}"; do
        local src="$REPO_DIR/$script"
        if [ -f "$src" ]; then
            cp "$src" "$scripts_dest/$script"
            chmod +x "$scripts_dest/$script" 2>/dev/null || true
            copied=$((copied + 1))
        fi
    done
    success "Copied $copied learning pipeline scripts to $scripts_dest/"
}

# =============================================================================
# Step 4c: Symlink ECC skills into native skills dirs for codex and pi
# =============================================================================

_migrate_flat_to_dir_skills() {
    # Migrate flat .md files to <name>/SKILL.md directory format.
    # Claude Code's /skills command only discovers directory-format skills.
    local skills_dir="$HOME/.claude/skills"
    [ ! -d "$skills_dir" ] && return 0
    local migrated=0
    for flat_file in "$skills_dir"/*.md; do
        [ ! -f "$flat_file" ] && continue
        local skill_name
        skill_name=$(basename "$flat_file" .md)
        # Skip learned/ subdirectory (uses flat .md by convention)
        [ "$skill_name" = "learned" ] && continue
        # Skip if directory already exists (already migrated)
        if [ -d "$skills_dir/$skill_name" ]; then
            rm -f "$flat_file"
            continue
        fi
        mkdir -p "$skills_dir/$skill_name"
        mv "$flat_file" "$skills_dir/$skill_name/SKILL.md"
        migrated=$((migrated + 1))
    done
    [ "$migrated" -gt 0 ] && success "Migrated $migrated flat .md skills to directory format"
    return 0
}

link_native_skills() {
    log "Step 4b: Linking ECC skills into native harness skill directories..."

    if [ ! -d "$ECC_DIR/skills" ]; then
        warn "ECC skills not installed, skipping native linking"
        return 0
    fi

    # Claude Code: ~/.claude/skills/<skill-name>/SKILL.md (directory format)
    # Claude Code's /skills command ONLY discovers directory-format skills,
    # NOT flat .md files. Migrate any stale flat files first.
    local claude_skills_dir="$HOME/.claude/skills"
    mkdir -p "$claude_skills_dir"
    _migrate_flat_to_dir_skills
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
        local dst_dir="$claude_skills_dir/$skill_name"
        local dst="$dst_dir/SKILL.md"
        if [ ! -f "$dst" ]; then
            mkdir -p "$dst_dir"
            cp "$src_file" "$dst"
            claude_count=$((claude_count + 1))
        fi
    done
    local total_count=$(find "$claude_skills_dir" -mindepth 1 -maxdepth 1 -type d ! -name 'learned' 2>/dev/null | wc -l | tr -d ' ')
    if [ "$claude_count" -eq 0 ] && [ "$total_count" -gt 0 ]; then
        success "Claude Code: all ECC skills already in ~/.claude/skills/ ($total_count total)"
    else
        success "Claude Code: $claude_count ECC skills installed to ~/.claude/skills/ ($total_count total)"
    fi

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
    # Claude Code ONLY discovers <name>/SKILL.md directory format
    if [ -d "$SCIENCE_DIR/scientific-skills" ]; then
        local science_count=0
        for dir in "$SCIENCE_DIR/scientific-skills"/*/; do
            skill_name=$(basename "$dir")
            [ ! -f "$dir/SKILL.md" ] && continue
            # Claude Code: directory format (<name>/SKILL.md)
            local dst_dir="$claude_skills_dir/$skill_name"
            local dst="$dst_dir/SKILL.md"
            if [ ! -f "$dst" ]; then
                mkdir -p "$dst_dir"
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

    # ClawBio Bioinformatics Skills: install into all harness native skill dirs
    if [ -d "$CLAWBIO_DIR/skills" ]; then
        local bio_count=0
        for dir in "$CLAWBIO_DIR/skills"/*/; do
            skill_name=$(basename "$dir")
            [ ! -f "$dir/SKILL.md" ] && continue
            # Claude Code: directory format (<name>/SKILL.md)
            local dst_dir="$claude_skills_dir/$skill_name"
            if [ ! -f "$dst_dir/SKILL.md" ]; then
                mkdir -p "$dst_dir"
                cp "$dir/SKILL.md" "$dst_dir/SKILL.md"
                # Copy Python scripts and examples if present (ClawBio includes executable scripts)
                cp -r "$dir/examples" "$dst_dir/" 2>/dev/null || true
                cp "$dir"/*.py "$dst_dir/" 2>/dev/null || true
                bio_count=$((bio_count + 1))
            fi
        done
        [ $bio_count -gt 0 ] && success "Claude Code: $bio_count ClawBio skills installed to ~/.claude/skills/"

        # OpenClaw: real copies (sanitize YAML like K-Dense skills)
        if [ -d "$HOME/.openclaw/workspace" ]; then
            local oc_bio_count=0
            for dir in "$CLAWBIO_DIR/skills"/*/; do
                skill_name=$(basename "$dir")
                [ ! -f "$dir/SKILL.md" ] && continue
                dst="$ws_skills/$skill_name"
                if [ ! -d "$dst" ]; then
                    mkdir -p "$dst"
                    if grep -q '^description: *[>|]' "$dir/SKILL.md" 2>/dev/null || \
                       grep -E '^[a-z_]+:' "$dir/SKILL.md" 2>/dev/null | grep -qvE '^(name|description|origin|tools|version|tags|trigger_keywords|metadata|compatibility|license|allowed-tools):'; then
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
                    cp "$dir"/*.py "$dst/" 2>/dev/null || true
                    cp -r "$dir/examples" "$dst/" 2>/dev/null || true
                    oc_bio_count=$((oc_bio_count + 1))
                fi
            done
            [ $oc_bio_count -gt 0 ] && success "OpenClaw: $oc_bio_count ClawBio skills copied to workspace"
        fi

        # Pi: symlink ClawBio skills
        if [ -d "$HOME/.pi/agent" ]; then
            local pi_bio_count=0
            for dir in "$CLAWBIO_DIR/skills"/*/; do
                skill_name=$(basename "$dir")
                [ ! -f "$dir/SKILL.md" ] && continue
                if [ ! -e "$HOME/.pi/agent/skills/$skill_name" ]; then
                    ln -s "$dir" "$HOME/.pi/agent/skills/$skill_name"
                    pi_bio_count=$((pi_bio_count + 1))
                fi
            done
            [ $pi_bio_count -gt 0 ] && success "Pi: $pi_bio_count ClawBio skills linked"
        fi

        # Codex: handled by update-ecc.sh
        if [ -d "$HOME/.codex/skills" ]; then
            log "Codex ClawBio skills will be synced by update-ecc.sh (proper YAML sanitization)"
        fi
    fi
}

# =============================================================================
# Step 5: Uninstall
# =============================================================================

uninstall() {
    log "Uninstalling skills layer..."

    # Remove shell integration from all possible rc files
    for rc_file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
        if [ -f "$rc_file" ]; then
            if grep -q "# Skills Layer" "$rc_file" 2>/dev/null; then
                sed -i.bak '/# Skills Layer/,/# End Skills Layer/d' "$rc_file" 2>/dev/null || true
                success "Removed shell integration from $rc_file"
            fi
        fi
    done

    # Remove installed skill library clones
    rm -rf "$ECC_DIR"
    rm -rf "$CURATED_DIR"
    rm -rf "$SCIENCE_DIR"
    rm -rf "$CLAWBIO_DIR"
    rm -rf "$SKILLS_CACHE_DIR"

    # Remove only ECC-originated skills from Claude Code native skills dir.
    # Does NOT rm -rf ~/.claude/skills to protect user-created and learned skills.
    if [ -d "$HOME/.claude/skills" ]; then
        local removed_count=0
        # Remove symlinks (Pi/ECC-style) and dirs we installed
        for entry in "$HOME/.claude/skills"/*/; do
            [ -L "$entry" ] && rm "$entry" && removed_count=$((removed_count + 1)) && continue
            [ -f "${entry}SKILL.md" ] && rm -rf "$entry" && removed_count=$((removed_count + 1))
        done
        success "Removed $removed_count installed skills from ~/.claude/skills/"
        # Remove the learned/ subdir only if user explicitly asks
        # (learned skills are personal — never auto-delete)
    fi

    # Remove copied learning pipeline scripts
    local scripts_dest="$HOME/.claude/scripts"
    for script in "sync-learned-skills.sh" "extract-conversation-skills.py" "safe-install.sh"; do
        [ -f "$scripts_dest/$script" ] && rm "$scripts_dest/$script" && success "Removed $scripts_dest/$script"
    done
    # Remove scripts dir if now empty
    rmdir "$scripts_dest" 2>/dev/null || true

    success "Uninstall complete"
    echo ""
    echo "Note: ~/.claude/skills/learned/ (personal learned skills) was preserved."
    echo "Run 'source ~/.zshrc' or 'source ~/.bashrc' or restart terminal to fully clean up."
}

# =============================================================================
# Step 6: Show usage
# =============================================================================

show_usage() {
    # Count skills
    ECC_COUNT=0
    ANTHROPIC_COUNT=0
    CODEX_COUNT=0
    SCIENCE_COUNT=0
    BIO_COUNT=0
    if [ -d "$ECC_DIR/skills" ]; then
        ECC_COUNT=$(find "$ECC_DIR/skills" -maxdepth 2 -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ -d "$CURATED_DIR/anthropic-official" ]; then
        ANTHROPIC_COUNT=$(find "$CURATED_DIR/anthropic-official" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ -d "$CURATED_DIR/openai-codex" ]; then
        CODEX_COUNT=$(find "$CURATED_DIR/openai-codex" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ -d "$SCIENCE_DIR/scientific-skills" ]; then
        SCIENCE_COUNT=$(find "$SCIENCE_DIR/scientific-skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ -d "$CLAWBIO_DIR/skills" ]; then
        BIO_COUNT=$(find "$CLAWBIO_DIR/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
    fi
    TOTAL_COUNT=$((ECC_COUNT + ANTHROPIC_COUNT + CODEX_COUNT + SCIENCE_COUNT + BIO_COUNT))

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
  - Anthropic skills:    $ANTHROPIC_COUNT
  - Codex skills:        $CODEX_COUNT
  - Scientific skills:    $SCIENCE_COUNT (K-Dense Agent Skills)
  - Bioinformatics skills: $BIO_COUNT (ClawBio)
  - Total:                $TOTAL_COUNT

Activate:  source $reload_rc   (or restart terminal)

All default commands now have skills:
  claude                    ollama launch claude
  openclaw                  ollama launch openclaw
  codex                     ollama launch codex
  pi                        ollama launch pi
  copilot                   ollama launch copilot
  ollama

To bypass skills (raw commands):
  command claude [args]
  command codex [args]
  command openclaw [args]
  command pi [args]
  command copilot [args]
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
install_bio_skills
create_loader
link_native_skills
setup_shell_integration || true
copy_scripts_to_claude_dir || true

show_usage
