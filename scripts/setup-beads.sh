#!/bin/bash
# =============================================================================
# setup-beads.sh — Install and configure beads (bd) for all harnesses
# =============================================================================
# Installs the beads CLI + beads-mcp Python package, then injects the beads
# MCP server into ~/.claude.json (Claude Code) and ~/.copilot/mcp-config.json
# (Copilot CLI). Initialises a .beads/ workspace if none exists.
#
# On macOS: installs via Homebrew (auto-installs Homebrew if missing).
# On Linux: installs via the official beads install script.
#
# Usage:
#   scripts/setup-beads.sh
#   scripts/setup-beads.sh --skip-init    # skip bd init
#   scripts/setup-beads.sh --force        # reinstall + overwrite existing MCP entry
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Platform detection
case "$(uname -s)" in
    Darwin*)                OS_TYPE="macOS" ;;
    Linux*)                 OS_TYPE="Linux" ;;
    MINGW*|MSYS*|CYGWIN*)  OS_TYPE="Windows" ;;
    *)                      OS_TYPE="Unknown" ;;
esac

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()     { echo -e "${BLUE}[BEADS]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

SKIP_INIT=false
FORCE=false
for arg in "$@"; do
    case $arg in
        --skip-init) SKIP_INIT=true ;;
        --force)     FORCE=true ;;
    esac
done

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   Beads Integration Setup            ║"
echo "╚══════════════════════════════════════╝"
echo ""

# =============================================================================
# Step 1: Ensure Homebrew is installed (macOS only)
# =============================================================================
IS_TTY=false
[ -t 0 ] && IS_TTY=true

if [ "$OS_TYPE" = "macOS" ]; then
    if ! command -v brew >/dev/null 2>&1; then
        if [ "$IS_TTY" = "false" ]; then
            warn "Homebrew not found and running non-interactively — install brew first: https://brew.sh"
            warn "Then re-run: scripts/setup-beads.sh"
            exit 1
        fi
        log "Homebrew not found — installing (interactive)..."
        log "This will run the official Homebrew installer from brew.sh"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Homebrew may install to /opt/homebrew (Apple Silicon) or /usr/local (Intel)
        if [ -f /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        if command -v brew >/dev/null 2>&1; then
            success "Homebrew installed: $(brew --version | head -1)"
        else
            error "Homebrew install failed. Install from https://brew.sh and re-run."
        fi
    else
        success "Homebrew found: $(brew --version | head -1)"
    fi
fi

# =============================================================================
# Step 2: Install beads CLI
# =============================================================================
if command -v bd >/dev/null 2>&1 && [ "$FORCE" != "true" ]; then
    success "beads (bd) already installed: $(bd --version 2>/dev/null || echo 'version unknown')"
else
    log "Installing beads CLI..."
    if [ "$OS_TYPE" = "macOS" ]; then
        brew install beads && success "beads installed via Homebrew" || warn "brew install beads failed — check https://github.com/gastownhall/beads"
    else
        # Linux: official install script
        if curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash; then
            success "beads installed via official install script"
        else
            warn "beads install failed — install manually from https://github.com/gastownhall/beads"
        fi
    fi
fi

# =============================================================================
# Step 3: Install beads-mcp (Python package — harness-agnostic MCP server)
# =============================================================================
BEADS_MCP_CMD=""

# Prefer uv tool install (isolated, no PEP 668 issues)
if command -v uv >/dev/null 2>&1; then
    log "Installing beads-mcp via uv..."
    if uv tool install beads-mcp 2>/dev/null; then
        success "beads-mcp installed via uv tool"
        BEADS_MCP_CMD="beads-mcp"
    else
        warn "uv tool install beads-mcp failed — trying pip3..."
    fi
fi

# Fallback: pip3
if [ -z "$BEADS_MCP_CMD" ] && command -v pip3 >/dev/null 2>&1; then
    log "Installing beads-mcp via pip3..."
    if pip3 install --quiet beads-mcp 2>/dev/null; then
        success "beads-mcp installed via pip3"
        BEADS_MCP_CMD="beads-mcp"
    else
        warn "pip3 install beads-mcp failed — trying with --user flag..."
        if pip3 install --quiet --user beads-mcp 2>/dev/null; then
            success "beads-mcp installed via pip3 --user"
            BEADS_MCP_CMD="beads-mcp"
        else
            warn "beads-mcp could not be installed — MCP integration will be skipped"
        fi
    fi
fi

if [ -n "$BEADS_MCP_CMD" ] && command -v beads-mcp >/dev/null 2>&1; then
    success "beads-mcp binary confirmed: $(command -v beads-mcp)"
elif [ -n "$BEADS_MCP_CMD" ]; then
    warn "beads-mcp installed but not in PATH yet — MCP entries will point to 'beads-mcp'"
    warn "Ensure ~/.local/bin or uv tool bin dir is in your PATH"
fi

# =============================================================================
# Step 4: Inject beads MCP entry into ~/.claude.json (Claude Code)
# =============================================================================
inject_mcp_entry() {
    local config_path="$1"
    local harness_name="$2"

    if [ ! -f "$config_path" ]; then
        warn "$config_path not found — skipping $harness_name MCP injection"
        return 0
    fi

    python3 << PYEOF
import json, os, sys

config_path = "$config_path"
force = $([[ "$FORCE" == "true" ]] && echo "True" || echo "False")

with open(config_path) as f:
    config = json.load(f)

key = "mcpServers"
if key not in config:
    config[key] = {}

if "beads" in config[key] and not force:
    print("beads MCP entry already present (skip — use --force to overwrite)")
    sys.exit(0)

config[key]["beads"] = {
    "command": "beads-mcp",
    "args": []
}

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

action = "Updated" if "beads" in config[key] else "Added"
print(f"{action} beads MCP entry in {config_path}")
PYEOF
}

if [ -n "$BEADS_MCP_CMD" ]; then
    log "Injecting beads MCP entry into Claude Code config..."
    inject_mcp_entry "$HOME/.claude.json" "Claude Code" && success "Claude Code: beads MCP configured" || warn "Claude Code MCP injection failed"

    COPILOT_CFG="$HOME/.copilot/mcp-config.json"
    if [ -f "$COPILOT_CFG" ]; then
        log "Injecting beads MCP entry into Copilot CLI config..."
        inject_mcp_entry "$COPILOT_CFG" "Copilot CLI" && success "Copilot CLI: beads MCP configured" || warn "Copilot CLI MCP injection failed"
    else
        warn "~/.copilot/mcp-config.json not found — run scripts/setup-copilot.sh first"
    fi
else
    warn "beads-mcp not available — skipping MCP injection"
    warn "Install beads-mcp manually: uv tool install beads-mcp"
fi

# =============================================================================
# Step 5: Initialise beads workspace in repo (stealth mode — no git ops)
# =============================================================================
if [ "$SKIP_INIT" = "true" ]; then
    log "Skipping bd init (--skip-init passed)"
elif ! command -v bd >/dev/null 2>&1; then
    warn "bd command not found — skipping bd init"
else
    if [ -d "$REPO_DIR/.beads" ]; then
        success "Beads workspace already initialised at $REPO_DIR/.beads/"
    else
        log "Initialising beads workspace (stealth mode)..."
        cd "$REPO_DIR"
        bd init --quiet --stealth 2>/dev/null && success "Beads workspace initialised (.beads/)" || warn "bd init failed — run 'bd init' manually in the repo"
    fi
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo "  beads CLI:   $(command -v bd 2>/dev/null || echo 'not in PATH')"
echo "  beads-mcp:   $(command -v beads-mcp 2>/dev/null || echo 'not in PATH')"
echo ""
echo "  Key commands:"
echo "    bd prime     → AI-optimised project context dump (use at session start)"
echo "    bd ready     → List open work items"
echo "    bd create 'Title' -p 2  → Create work item (priority 1=high, 3=low)"
echo "    bd close <id>           → Close completed item"
echo ""
log "Restart Claude Code or Copilot CLI for MCP changes to take effect"
echo ""
