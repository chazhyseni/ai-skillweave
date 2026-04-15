#!/bin/bash
# =============================================================================
# setup-claude-desktop.sh — Add MCP servers + skills to Claude Desktop app
# =============================================================================
# Standalone setup for the Claude Desktop GUI app (separate from CLI install.sh).
# Adds MCP servers to the Desktop config and builds curated skills for a Project.
#
# Cross-platform:
#   macOS:   ~/Library/Application Support/Claude/claude_desktop_config.json
#   Linux:   ~/.config/Claude/claude_desktop_config.json
#   Windows: %APPDATA%\Claude\claude_desktop_config.json  (run via Git Bash/WSL)
#
# Usage:
#   ./scripts/setup-claude-desktop.sh                    # Full setup (MCP + skills)
#   ./scripts/setup-claude-desktop.sh --mcp-only         # MCP servers only
#   ./scripts/setup-claude-desktop.sh --skills-only      # Build skills file only
#   ./scripts/setup-claude-desktop.sh --tier essential    # Minimal skills (~6K tokens)
#   ./scripts/setup-claude-desktop.sh --tier standard     # Agents + top commands (~54K tokens)
#   ./scripts/setup-claude-desktop.sh --tier full         # All universal skills (~89K tokens, default)
#   ./scripts/setup-claude-desktop.sh --force             # Overwrite existing MCP entries
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_DIR/configs/claude-desktop-mcp-servers.json"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()     { echo -e "${BLUE}[DESKTOP]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# =============================================================================
# Parse arguments
# =============================================================================
FORCE=false
MCP_ONLY=false
SKILLS_ONLY=false
TIER="full"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)       FORCE=true; shift ;;
        --mcp-only)    MCP_ONLY=true; shift ;;
        --skills-only) SKILLS_ONLY=true; shift ;;
        --tier)        TIER="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: setup-claude-desktop.sh [--mcp-only] [--skills-only] [--tier essential|standard|full] [--force]"
            exit 0
            ;;
        *) shift ;;
    esac
done

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Claude Desktop App — MCP + Skills Setup               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# Detect platform and config path
# =============================================================================
detect_config_path() {
    local os_type
    case "$(uname -s)" in
        Darwin*)  os_type="macOS" ;;
        Linux*)   os_type="Linux" ;;
        MINGW*|MSYS*|CYGWIN*)  os_type="Windows" ;;
        *)        os_type="Unknown" ;;
    esac

    case "$os_type" in
        macOS)
            DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
            ;;
        Linux)
            DESKTOP_CONFIG="$HOME/.config/Claude/claude_desktop_config.json"
            ;;
        Windows)
            if [ -n "$APPDATA" ]; then
                DESKTOP_CONFIG="$APPDATA/Claude/claude_desktop_config.json"
            else
                DESKTOP_CONFIG="$HOME/AppData/Roaming/Claude/claude_desktop_config.json"
            fi
            ;;
        *)
            error "Unsupported OS: $(uname -s). Supported: macOS, Linux, Windows (Git Bash/WSL)"
            ;;
    esac

    log "Platform: $os_type"
    log "Config:   $DESKTOP_CONFIG"
}

detect_config_path

# =============================================================================
# Determine CA cert path (Zscaler or system default)
# =============================================================================
CA_CERT=""
if [ -f "$HOME/.mamba_ca_bundle.pem" ]; then
    CA_CERT="$HOME/.mamba_ca_bundle.pem"
elif [ -f "/etc/ssl/certs/ca-certificates.crt" ]; then
    CA_CERT="/etc/ssl/certs/ca-certificates.crt"
fi

# =============================================================================
# Part 1: MCP Servers
# =============================================================================
setup_mcp() {
    if [ ! -f "$DESKTOP_CONFIG" ]; then
        # Check if Claude Desktop is installed but config doesn't exist yet
        local config_dir
        config_dir="$(dirname "$DESKTOP_CONFIG")"
        if [ -d "$config_dir" ]; then
            log "Creating config file (Claude Desktop installed but no config yet)..."
            echo '{}' > "$DESKTOP_CONFIG"
        else
            warn "Claude Desktop not installed (directory not found: $config_dir)"
            warn "Install Claude Desktop from https://claude.ai/download then re-run"
            return 1
        fi
    fi

    command -v python3 >/dev/null 2>&1 || error "python3 not found"
    [ -f "$TEMPLATE" ] || error "Template not found: $TEMPLATE"

    # Backup
    local backup="${DESKTOP_CONFIG}.bak_$(date +%Y%m%d_%H%M%S)"
    cp "$DESKTOP_CONFIG" "$backup"
    success "Backup: $backup"

    # Apply MCP servers
    python3 << PYEOF
import json, os, sys

config_path = """$DESKTOP_CONFIG"""
template_path = "$TEMPLATE"
cli_config_path = os.path.expanduser("~/.claude.json")
ca_cert = "$CA_CERT"
home = os.path.expanduser("~")
force = $([[ "$FORCE" == "true" ]] && echo "True" || echo "False")

with open(config_path) as f:
    config = json.load(f)

with open(template_path) as f:
    template = json.load(f)

if "mcpServers" not in config:
    config["mcpServers"] = {}

# Load CLI config to copy API-key servers (github, exa-web-search)
api_key_servers = {}
if os.path.exists(cli_config_path):
    try:
        with open(cli_config_path) as f:
            cli_config = json.load(f)
        cli_mcp = cli_config.get("mcpServers", {})
        for name in ["github", "exa-web-search"]:
            if name in cli_mcp:
                api_key_servers[name] = cli_mcp[name]
    except Exception:
        pass

# Merge template servers
servers = template.get("mcpServers", {})
added, updated, skipped = [], [], []

for name, cfg in {**servers, **api_key_servers}.items():
    # Substitute placeholders
    cfg_str = json.dumps(cfg)
    cfg_str = cfg_str.replace("{{HOME}}", home)
    cfg_str = cfg_str.replace("{{CA_CERT_PATH}}", ca_cert if ca_cert else "")
    cfg = json.loads(cfg_str)

    # Remove empty CA cert envs
    if "env" in cfg and cfg["env"].get("NODE_EXTRA_CA_CERTS") == "":
        del cfg["env"]["NODE_EXTRA_CA_CERTS"]
        if not cfg["env"]:
            del cfg["env"]

    if name in config["mcpServers"] and not force:
        skipped.append(name)
    else:
        action = "updated" if name in config["mcpServers"] else "added"
        config["mcpServers"][name] = cfg
        (updated if action == "updated" else added).append(name)

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

print(f"Added:   {added}")
print(f"Updated: {updated}")
print(f"Skipped: {skipped}")
total = list(config["mcpServers"].keys())
print(f"Total MCP servers: {len(total)} — {total}")
if api_key_servers:
    print(f"API-key servers copied from CLI config: {list(api_key_servers.keys())}")
PYEOF

    success "MCP servers applied to Claude Desktop config"
    echo ""
    log "Restart Claude Desktop for changes to take effect."
}

# =============================================================================
# Part 2: Build curated skills file
# =============================================================================
build_skills() {
    log "Building curated skills (tier: $TIER)..."
    bash "$REPO_DIR/scripts/build-desktop-skills.sh" --tier "$TIER"
}

# =============================================================================
# Execute
# =============================================================================
if ! $SKILLS_ONLY; then
    echo ""
    log "Setting up MCP servers..."
    echo ""
    setup_mcp
fi

if ! $MCP_ONLY; then
    echo ""
    log "Building curated skills for Desktop Project..."
    echo ""
    build_skills
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Claude Desktop Setup Complete                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Next steps:"
echo "    1. Restart Claude Desktop app"
echo "    2. MCP servers will appear in Claude Desktop settings"
echo "    3. To add skills: create a Project in Claude Desktop,"
echo "       then paste the contents of:"
echo "       $REPO_DIR/configs/claude-desktop-project-instructions.md"
echo "       as the Project's custom instructions."
echo ""
echo "  Token economics:"
echo "    MCP servers: zero tokens until invoked"
echo "    Skills (tier=$TIER): see file size above — cached after first turn"
echo ""
