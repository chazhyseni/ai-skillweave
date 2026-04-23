#!/bin/bash
# =============================================================================
# setup-mcp.sh — Inject MCP servers into Claude Code (~/.claude.json)
# =============================================================================
# Merges configs/claude-mcp-servers.json into the mcpServers key of
# ~/.claude.json. Safe to re-run (idempotent — won't overwrite existing entries).
#
# Usage:
#   scripts/setup-mcp.sh [--force]
#   --force : overwrite existing MCP server entries with template values
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_DIR/configs/claude-mcp-servers.json"
TARGET="$HOME/.claude.json"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()     { echo -e "${BLUE}[MCP]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

FORCE=false
[[ "$*" == *"--force"* ]] && FORCE=true

# Determine CA cert path (Zscaler or system default)
CA_CERT=""
if [ -f "$HOME/.mamba_ca_bundle.pem" ]; then
    CA_CERT="$HOME/.mamba_ca_bundle.pem"
elif [ -f "/etc/ssl/certs/ca-certificates.crt" ]; then
    CA_CERT="/etc/ssl/certs/ca-certificates.crt"
fi

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   MCP Setup for Claude Code          ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Prereqs
command -v python3 >/dev/null 2>&1 || error "python3 not found"
[ -f "$TARGET" ] || error "~/.claude.json not found. Install Claude Code first."
[ -f "$TEMPLATE" ] || error "Template not found: $TEMPLATE"

# Backup
BACKUP="$TARGET.bak_mcp_$(date +%Y%m%d_%H%M%S)"
cp "$TARGET" "$BACKUP"
success "Backup: $BACKUP"

# Apply
python3 << PYEOF
import json, os, sys

target_path = os.path.expanduser("~/.claude.json")
template_path = "$TEMPLATE"
ca_cert = "$CA_CERT"
home = os.path.expanduser("~")
npx_path = "$(which npx 2>/dev/null || echo "npx")"
force = $([[ "$FORCE" == "true" ]] && echo "True" || echo "False")

with open(target_path) as f:
    config = json.load(f)

with open(template_path) as f:
    template = json.load(f)

if "mcpServers" not in config:
    config["mcpServers"] = {}

servers = template.get("mcpServers", {})
added, updated, skipped = [], [], []

for name, cfg in servers.items():
    # Substitute placeholders
    cfg_str = json.dumps(cfg)
    cfg_str = cfg_str.replace("{{HOME}}", home)
    cfg_str = cfg_str.replace("{{CA_CERT_PATH}}", ca_cert if ca_cert else "")
    cfg_str = cfg_str.replace("{{NPX_PATH}}", npx_path)
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

# Enable global prompt cache for system prompt (skills injection)
config.setdefault("cachedGrowthBookFeatures", {})["tengu_system_prompt_global_cache"] = True

with open(target_path, "w") as f:
    json.dump(config, f, indent=2)

print(f"Added:   {added}")
print(f"Updated: {updated}")
print(f"Skipped: {skipped}")
print(f"Total active MCP servers: {list(config['mcpServers'].keys())}")
print(f"tengu_system_prompt_global_cache: True (skills injection cached across sessions)")
PYEOF

success "MCP servers applied to $TARGET"
echo ""
log "Restart Claude Code (or run: claude) for changes to take effect."
echo ""
