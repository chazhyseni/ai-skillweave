#!/bin/bash
# =============================================================================
# install.sh — Master setup for Ollama Agent Harness
# =============================================================================
# One-command setup for all AI agent harnesses on a new machine.
# Configures: Claude Code (MCP), OpenClaw, Pi, Codex, shell skills layer.
#
# Requirements:
#   - Ollama installed and running (https://ollama.com)
#   - At least one model: ollama pull <model-name>
#   - Claude Code, OpenClaw, Pi, and/or Codex installed as needed
#
# Usage:
#   ./install.sh                           # Full setup (all harnesses)
#   ./install.sh --model llama3.2:3b       # Use a specific Ollama model
#   ./install.sh --skip-skills             # Skip ECC skills installation
#   ./install.sh --only claude             # Only configure claude
#   ./install.sh --only openclaw           # Only configure openclaw
#   ./install.sh --uninstall               # Remove shell integrations
#   ./install.sh --verify                  # Run health check only
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()     { echo -e "${BLUE}[INSTALL]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo ""; echo -e "${CYAN}═══════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}═══════════════════════════════════════${NC}"; }

# =============================================================================
# Parse arguments
# =============================================================================
OLLAMA_MODEL="qwen3.5:397b-cloud"
SKIP_SKILLS=false
ONLY_TARGET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)       OLLAMA_MODEL="$2"; shift 2 ;;
        --skip-skills) SKIP_SKILLS=true; shift ;;
        --only)        ONLY_TARGET="$2"; shift 2 ;;
        --uninstall)
            "$REPO_DIR/safe-install.sh" --uninstall
            exit 0
            ;;
        --verify)
            bash "$REPO_DIR/scripts/verify.sh"
            exit 0
            ;;
        --help|-h)
            echo "Usage: ./install.sh [--model MODEL] [--skip-skills] [--only TARGET] [--uninstall] [--verify]"
            exit 0
            ;;
        *) shift ;;
    esac
done

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Ollama Agent Harness — Full Setup                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
log "Model: $OLLAMA_MODEL"
log "Repo:  $REPO_DIR"
echo ""

# =============================================================================
# Step 0: Preflight checks
# =============================================================================
section "Preflight"

command -v python3 >/dev/null 2>&1 || error "python3 required (brew install python3)"
command -v node >/dev/null 2>&1 || warn "node not found — npx-based MCP servers won't work (brew install node)"
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
        warn "Ollama server not running — start it: open /Applications/Ollama.app"
        warn "Continuing setup; start Ollama before using harnesses"
    fi
else
    error "ollama not installed. Install from https://ollama.com then re-run."
fi

# Disable Zscaler tray if running (no sudo needed)
if launchctl list 2>/dev/null | grep -q "zscaler"; then
    log "Detected Zscaler — disabling tray (no sudo needed)..."
    bash "$REPO_DIR/scripts/disable-zscaler.sh" --tray 2>/dev/null || true
fi

# =============================================================================
# Step 1: Skills Layer (ECC + shell wrappers)
# =============================================================================

should_run() {
    [ -z "$ONLY_TARGET" ] || [ "$ONLY_TARGET" = "$1" ]
}

if ! $SKIP_SKILLS && should_run "skills"; then
    section "Skills Layer"
    # safe-install.sh exits non-zero when 'source ~/.zshrc' fails in a non-interactive
    # subshell — this is expected and harmless. Ignore the exit code.
    bash "$REPO_DIR/safe-install.sh" || true
    success "ECC skills + shell wrappers installed (run: source ~/.zshrc to activate)"
    # Rebuild cache with full skill counts (safe-install.sh caps Codex at 100).
    # update-ecc.sh also restores ECC working tree to actual HEAD.
    log "Rebuilding skills cache with full counts..."
    bash "$REPO_DIR/scripts/update-ecc.sh" --force 2>/dev/null || true
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
# Step 2: Claude Code MCP
# =============================================================================
if should_run "claude"; then
    section "Claude Code MCP"
    if [ -f "$HOME/.claude.json" ]; then
        bash "$REPO_DIR/scripts/setup-mcp.sh" && success "Claude Code MCP configured"
    else
        warn "~/.claude.json not found — run Claude Code once to initialize, then re-run install.sh"
    fi
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
    bash "$REPO_DIR/scripts/setup-codex.sh" --model "$OLLAMA_MODEL" && success "Codex configured" || warn "Codex setup skipped (not installed yet)"
fi

# =============================================================================
# Step 5: Pi
# =============================================================================
if should_run "pi"; then
    section "Pi"
    bash "$REPO_DIR/scripts/setup-pi.sh" --model "$OLLAMA_MODEL" && success "Pi configured" || warn "Pi setup skipped (not installed yet)"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Setup Complete                                         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Reload shell:   source ~/.zshrc"
echo ""
echo "  Launch harnesses:"
echo "    ollama launch claude      → Claude Code with MCP + skills"
echo "    ollama launch openclaw    → OpenClaw with web tools + subagents"
echo "    ollama launch pi          → Pi with subagents"
echo "    ollama launch codex       → Codex via ollama-launch provider"
echo ""
echo "  Health check:   ./install.sh --verify"
echo ""
echo "  Zscaler (if needed after reboot):"
echo "    scripts/disable-zscaler.sh"
echo "    # Then (in Terminal with sudo):"
echo "    sudo launchctl unload /Library/LaunchDaemons/com.zscaler.service.plist"
echo "    sudo launchctl unload /Library/LaunchDaemons/com.zscaler.tunnel.plist"
echo ""
