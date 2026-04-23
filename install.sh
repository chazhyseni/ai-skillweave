#!/bin/bash
# =============================================================================
# install.sh — Master setup for Ollama Agent Harness
# =============================================================================
# One-command setup for all AI agent harnesses on a new machine.
# Configures: Claude Code (MCP), OpenClaw, Pi, Codex, Copilot CLI, shell skills layer.
#
# Requirements:
#   - Ollama installed and running (https://ollama.com)
#   - At least one model: ollama pull <model-name>
#   - Claude Code, OpenClaw, Pi, Codex, and/or Copilot installed as needed
#
# Usage:
#   ./install.sh                           # Full setup (all harnesses + all skills)
#   ./install.sh --without-science         # Skip K-Dense scientific skills
#   ./install.sh --model llama3.2:3b       # Use a specific Ollama model
#   ./install.sh --skip-skills             # Skip ECC skills installation
#   ./install.sh --only claude             # Only configure claude
#   ./install.sh --only openclaw           # Only configure openclaw
#   ./install.sh --uninstall               # Remove shell integrations
#   ./install.sh --verify                  # Run health check only
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Platform detection
# =============================================================================
case "$(uname -s)" in
    Darwin*)                 OS_TYPE="macOS" ;;
    Linux*)                  OS_TYPE="Linux" ;;
    MINGW*|MSYS*|CYGWIN*)   OS_TYPE="Windows" ;;  # untested; use WSL
    *)                       OS_TYPE="Unknown" ;;
esac

# Detect user's login shell for RC file references
case "${SHELL##*/}" in
    zsh)  USER_SHELL="zsh";  SHELL_RC="~/.zshrc" ;;
    bash) USER_SHELL="bash"; SHELL_RC="~/.bashrc" ;;
    *)    USER_SHELL="bash"; SHELL_RC="~/.bashrc" ;;
esac

# Platform-aware package install hint
case "$OS_TYPE" in
    macOS)   PKG_HINT="brew install" ;;
    Linux)
        if command -v apt-get >/dev/null 2>&1; then
            PKG_HINT="apt-get install"
        elif command -v dnf >/dev/null 2>&1; then
            PKG_HINT="dnf install"
        elif command -v pacman >/dev/null 2>&1; then
            PKG_HINT="pacman -S"
        else
            PKG_HINT="your package manager to install"
        fi
        ;;
    Windows) PKG_HINT="your package manager to install" ;;
    *)       PKG_HINT="your package manager to install" ;;
esac

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()     { echo -e "${BLUE}[INSTALL]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo ""; echo -e "${CYAN}═══════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}═══════════════════════════════════════${NC}"; }

# =============================================================================
# Parse arguments
# =============================================================================
OLLAMA_MODEL="qwen3.6"
SKIP_SKILLS=false
WITH_SCIENCE=true
WITH_CURATED=true
WITH_BIO=true
WITH_LEARN=true
ONLY_TARGET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)            OLLAMA_MODEL="$2"; shift 2 ;;
        --skip-skills)      SKIP_SKILLS=true; shift ;;
        --with-science)     WITH_SCIENCE=true; shift ;;
        --without-science)  WITH_SCIENCE=false; shift ;;
        --with-curated)     WITH_CURATED=true; shift ;;
        --without-curated)  WITH_CURATED=false; shift ;;
        --with-bio)         WITH_BIO=true; shift ;;
        --without-bio)      WITH_BIO=false; shift ;;
        --learn)            WITH_LEARN=true; shift ;;
        --no-learn)         WITH_LEARN=false; shift ;;
        --only)             ONLY_TARGET="$2"; shift 2 ;;
        --uninstall)
            "$REPO_DIR/safe-install.sh" --uninstall
            exit 0
            ;;
        --verify)
            bash "$REPO_DIR/scripts/verify.sh"
            exit 0
            ;;
        --help|-h)
            echo "Usage: ./install.sh [--model MODEL] [--skip-skills] [--with-science] [--without-science] [--with-bio] [--without-bio] [--only TARGET] [--uninstall] [--verify]"
            echo ""
            echo "  --with-science     Include K-Dense scientific skills (default)"
            echo "  --without-science  Skip K-Dense scientific skills"
            echo "  --with-bio         Include ClawBio bioinformatics skills (default)"
            echo "  --without-bio      Skip ClawBio bioinformatics skills"
            exit 0
            ;;
        *) shift ;;
    esac
done

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   ai-skillweave — Full Setup                           ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
log "Platform: $OS_TYPE ($USER_SHELL)"
log "Model:    $OLLAMA_MODEL"
log "Repo:     $REPO_DIR"
echo ""

if [ "$OS_TYPE" = "Windows" ]; then
    warn "Native Windows detected. This installer targets bash-based systems."
    warn "For best results, run inside WSL (Windows Subsystem for Linux)."
    warn "Continuing anyway — some steps may not apply."
    echo ""
fi

# =============================================================================
# Step 0a: Bootstrap prerequisites (git, node/npm, ollama, python3)
# =============================================================================
section "Bootstrap"

_install_if_missing() {
    local cmd="$1"
    local name="$2"
    local install_cmd="$3"
    if command -v "$cmd" >/dev/null 2>&1; then
        success "$name already installed: $(command -v "$cmd")"
        return 0
    fi
    log "Installing $name..."
    if eval "$install_cmd"; then
        success "$name installed"
        return 0
    else
        warn "$name installation failed — install manually, then re-run"
        return 1
    fi
}

# --- git ---
if [ "$OS_TYPE" = "macOS" ]; then
    _install_if_missing git "git" "brew install git"
else
    if command -v apt-get >/dev/null 2>&1; then
        _install_if_missing git "git" "sudo apt-get update -qq && sudo apt-get install -y -qq git"
    elif command -v dnf >/dev/null 2>&1; then
        _install_if_missing git "git" "sudo dnf install -y git"
    elif command -v pacman >/dev/null 2>&1; then
        _install_if_missing git "git" "sudo pacman -S --noconfirm git"
    fi
fi

# --- node + npm ---
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    log "Node.js/npm not found — installing..."
    if [ "$OS_TYPE" = "macOS" ]; then
        brew install node 2>/dev/null || warn "brew install node failed"
    else
        # Use NodeSource setup for LTS Node 22
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash - 2>/dev/null && \
            apt-get install -y nodejs 2>/dev/null || \
            warn "NodeSource install failed — install node manually"
    fi
    # Verify
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        success "Node.js $(node --version) + npm $(npm --version) installed"
    else
        warn "Node.js/npm still not available — npx-based MCP servers won't work"
    fi
else
    success "Node.js $(node --version) + npm $(npm --version) already installed"
fi

# --- ollama ---
if ! command -v ollama >/dev/null 2>&1; then
    log "Ollama not found — installing..."
    curl -fsSL https://ollama.com/install.sh | sh && \
        success "Ollama installed" || \
        warn "Ollama install failed — install manually from https://ollama.com"
else
    success "Ollama already installed: $(command -v ollama)"
fi

# --- python3 + pip ---
if ! command -v python3 >/dev/null 2>&1; then
    log "python3 not found — installing..."
    if [ "$OS_TYPE" = "macOS" ]; then
        brew install python3 2>/dev/null || warn "brew install python3 failed"
    else
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update -qq && sudo apt-get install -y -qq python3 python3-pip python3-venv
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y python3 python3-pip
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm python python-pip
        fi
    fi
fi
if command -v python3 >/dev/null 2>&1; then
    success "python3: $(command -v python3)"
else
    error "python3 is required but could not be installed automatically"
fi

# =============================================================================
# Step 0: Preflight checks
# =============================================================================
section "Preflight"

command -v python3 >/dev/null 2>&1 || error "python3 required ($PKG_HINT python3)"

# Install Python dependencies for SOTA v3 auto-learning pipeline
log "Installing Python dependencies for skill extraction (sentence-transformers, scikit-learn)..."
_install_python_deps() {
    local pkgs="sentence-transformers>=3.0.0 scikit-learn>=1.5.0"
    # Detect virtualenv: --user is forbidden inside venv/conda
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
        # Try multiple pip invocation strategies; show errors so user can diagnose
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

command -v node >/dev/null 2>&1 || warn "node not found — npx-based MCP servers won't work ($PKG_HINT node)"
command -v git >/dev/null 2>&1 || warn "git not found — ECC skills install will be skipped"

if command -v ollama >/dev/null 2>&1; then
    success "ollama: $(command -v ollama)"
    if curl -s --max-time 3 http://localhost:11434/api/status >/dev/null 2>&1; then
        success "Ollama server: running"

        # Check if requested model is available
        if ollama list 2>/dev/null | grep -q "^${OLLAMA_MODEL}"; then
            success "Model available: $OLLAMA_MODEL"
        else
            warn "Model '$OLLAMA_MODEL' not in local list (may be cloud model — OK)"
            warn "If local model needed: ollama pull $OLLAMA_MODEL"
        fi
    else
        if [ "$OS_TYPE" = "macOS" ]; then
            warn "Ollama server not running — start it: open /Applications/Ollama.app"
        else
            warn "Ollama server not running — start it: ollama serve"
        fi
        warn "Continuing setup; start Ollama before using harnesses"
    fi
else
    warn "ollama not installed — install from https://ollama.com"
    warn "Continuing setup without Ollama; harnesses that need it will fail at runtime"
fi

# Disable Zscaler tray if running (macOS only, no sudo needed)
if [ "$OS_TYPE" = "macOS" ] && launchctl list 2>/dev/null | grep -q "zscaler"; then
    log "Detected Zscaler — disabling tray (no sudo needed)..."
    bash "$REPO_DIR/scripts/disable-zscaler.sh" --tray 2>/dev/null || true
fi

# =============================================================================
# Step 0b: Pre-install npx-based MCP servers globally (prevents timeout on first launch)
# =============================================================================
if command -v npm >/dev/null 2>&1; then
    log "Pre-installing MCP server packages globally (prevents first-launch timeouts)..."
    # Install silently in background; failures are non-fatal (npx will fallback)
    npm install -g @modelcontextprotocol/server-memory \
        @modelcontextprotocol/server-sequential-thinking \
        @upstash/context7-mcp@latest \
        @playwright/mcp \
        codesight \
        token-optimizer-mcp 2>/dev/null || warn "Some MCP packages failed to pre-install (npx fallback will work but may be slower on first launch)"
    success "MCP server packages pre-installed"
else
    warn "npm not found — MCP servers will be installed on first launch (may timeout)"
fi

# =============================================================================
# Harness installer helper
# =============================================================================
install_harness() {
    local name="$1"
    local cmd="$2"
    local install_cmd="$3"

    if command -v "$cmd" >/dev/null 2>&1; then
        success "$name already installed: $(command -v "$cmd")"
        return 0
    fi

    if ! command -v npm >/dev/null 2>&1; then
        warn "npm not found — cannot auto-install $name"
        warn "Install manually, then re-run install.sh"
        return 1
    fi

    log "Installing $name..."
    if eval "$install_cmd"; then
        success "$name installed"
        return 0
    else
        warn "$name installation failed — install manually, then re-run"
        return 1
    fi
}

# =============================================================================
# Step 1: Skills Layer (ECC + shell wrappers)
# =============================================================================

should_run() {
    [ -z "$ONLY_TARGET" ] || [ "$ONLY_TARGET" = "$1" ]
}

if ! $SKIP_SKILLS && should_run "skills"; then
    section "Skills Layer"
    # safe-install.sh may exit non-zero when 'source <rc>' fails in a non-interactive
    # subshell — this is expected and harmless. Capture exit code to report real failures.
    safe_exit=0
    SAFE_ARGS=""
    $WITH_SCIENCE && SAFE_ARGS="$SAFE_ARGS --with-science"
    $WITH_CURATED && SAFE_ARGS="$SAFE_ARGS --with-curated"
    $WITH_BIO && SAFE_ARGS="$SAFE_ARGS --with-bio"
    bash "$REPO_DIR/safe-install.sh" $SAFE_ARGS || safe_exit=$?
    if [ "$safe_exit" -eq 0 ]; then
        success "ECC skills + shell wrappers installed (run: source $SHELL_RC to activate)"
    else
        warn "safe-install.sh exited with code $safe_exit — shell integration may need manual source $SHELL_RC"
    fi
    # Rebuild cache with full skill counts (safe-install.sh caps Codex at 100).
    # update-ecc.sh also restores ECC working tree to actual HEAD.
    log "Rebuilding skills cache with full counts..."
    bash "$REPO_DIR/scripts/update-ecc.sh" --force || true
    success "Skills cache rebuilt (all sources, no caps)"
else
    log "Skipping skills layer"
fi

# =============================================================================
# Step 1b: Ollama integration→model mapping
# =============================================================================
if should_run "ollama" || [ -z "$ONLY_TARGET" ]; then
    section "Ollama Integrations"
    bash "$REPO_DIR/scripts/setup-ollama-config.sh" && success "Ollama integrations configured" || warn "Ollama config skipped (Ollama not started yet)"
fi

# =============================================================================
# Step 2: Claude Code MCP + Global Instructions
# =============================================================================
if should_run "claude"; then
    section "Claude Code"
    install_harness "Claude Code" "claude" "npm install -g @anthropic-ai/claude-code"
    if [ -f "$HOME/.claude.json" ]; then
        bash "$REPO_DIR/scripts/setup-mcp.sh" && success "Claude Code MCP configured" || warn "MCP setup skipped (run Claude Code once, then re-run)"
    else
        warn "~/.claude.json not found — run Claude Code once to initialize, then re-run install.sh"
    fi
    # Global CLAUDE.md: proactive MCP usage + conciseness + token discipline
    bash "$REPO_DIR/scripts/setup-claude-md.sh" && success "Global CLAUDE.md installed" || warn "CLAUDE.md setup skipped"
    # Pre-tool-use hooks: enforce codesight before broad Glob/Grep searches
    bash "$REPO_DIR/scripts/setup-hooks.sh" && success "Claude Code hooks installed" || warn "Hooks setup skipped"
    
    # BMO-style learning capture hooks (real-time correction detection)
    bash "$REPO_DIR/scripts/setup-learning-hook.sh" && success "BMO learning capture hooks configured" || warn "Learning hook setup skipped"
fi

# =============================================================================
# Step 3: OpenClaw
# =============================================================================
if should_run "openclaw"; then
    section "OpenClaw"
    bash "$REPO_DIR/scripts/setup-openclaw.sh" --model "$OLLAMA_MODEL" && success "OpenClaw configured" || warn "OpenClaw setup skipped (not installed yet)"
fi

# =============================================================================
# Step 4: Codex
# =============================================================================
if should_run "codex"; then
    section "Codex"
    install_harness "Codex CLI" "codex" "npm install -g @openai/codex"
    bash "$REPO_DIR/scripts/setup-codex.sh" --model "$OLLAMA_MODEL" && success "Codex configured" || warn "Codex setup skipped (not installed yet)"
fi

# =============================================================================
# Step 5: Pi
# =============================================================================
if should_run "pi"; then
    section "Pi"
    install_harness "Pi" "pi" "npm install -g @mariozechner/pi-coding-agent"
    bash "$REPO_DIR/scripts/setup-pi.sh" --model "$OLLAMA_MODEL" && success "Pi configured" || warn "Pi setup skipped (not installed yet)"
fi

# =============================================================================
# Step 6: Copilot CLI
# =============================================================================
if should_run "copilot"; then
    section "Copilot CLI"
    install_harness "Copilot CLI" "copilot" "npm install -g @github/copilot"
    bash "$REPO_DIR/scripts/setup-copilot.sh" && success "Copilot CLI MCP configured" || warn "Copilot setup skipped (not installed yet)"
fi

# =============================================================================
# =============================================================================
# Step 5: Cleanup stale/invalid skills from previous installs
# =============================================================================
if [ -f "$REPO_DIR/scripts/cleanup-invalid-skills.sh" ]; then
    log "Cleaning up invalid skills from previous installs..."
    bash "$REPO_DIR/scripts/cleanup-invalid-skills.sh" 2>/dev/null || warn "Skill cleanup had issues (non-fatal)"
fi

# Done
# =============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Setup Complete ($OS_TYPE / $USER_SHELL)"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Reload shell:   source $SHELL_RC"
echo ""
echo "  Launch harnesses:"
echo "    ollama launch claude      → Claude Code with MCP + skills"
echo "    ollama launch openclaw    → OpenClaw with web tools + subagents"
echo "    ollama launch pi          → Pi with subagents"
echo "    ollama launch codex       → Codex via ollama-launch provider"
echo "    ollama launch copilot     → Copilot CLI with MCP servers"
echo ""
echo "  Health check:   ./install.sh --verify"
echo ""
if [ "$OS_TYPE" = "macOS" ]; then
    echo "  Zscaler (if needed after reboot):"
    echo "    scripts/disable-zscaler.sh"
    echo "    # Then (in Terminal with sudo):"
    echo "    sudo launchctl unload /Library/LaunchDaemons/com.zscaler.service.plist"
    echo "    sudo launchctl unload /Library/LaunchDaemons/com.zscaler.tunnel.plist"
    echo ""
fi
