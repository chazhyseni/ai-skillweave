#!/bin/bash
# setup-copilot.sh — Configure MCP servers for GitHub Copilot CLI
# =============================================================================
# Writes MCP server config to ~/.copilot/mcp-config.json (read automatically
# by copilot on launch; augments built-in github-mcp-server).
#
# Usage:
#   scripts/setup-copilot.sh [--force]
#   --force : overwrite existing MCP server entries with template values
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_DIR/configs/copilot-mcp-config.json"
TARGET="$HOME/.copilot/mcp-config.json"

log()     { echo -e "\033[1;34m[COPILOT]\033[0m $1"; }
success() { echo -e "\033[1;32m[OK]\033[0m $1"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m $1"; }

if [ ! -f "$TEMPLATE" ]; then
    warn "Template not found: $TEMPLATE"
    exit 1
fi

FORCE=false
[[ "$*" == *"--force"* ]] && FORCE=true

# Ensure Copilot config directory exists
mkdir -p "$(dirname "$TARGET")"

# Determine CA cert path (Zscaler or system default)
CA_CERT=""
if [ -f "$HOME/.mamba_ca_bundle.pem" ]; then
    CA_CERT="$HOME/.mamba_ca_bundle.pem"
elif [ -f "/etc/ssl/certs/ca-certificates.crt" ]; then
    CA_CERT="/etc/ssl/certs/ca-certificates.crt"
fi

log "Installing MCP servers for Copilot CLI..."

python3 << PYEOF
import json, os, sys

template_path = "$TEMPLATE"
target_path = "$TARGET"
ca_cert = "$CA_CERT"
home = os.path.expanduser("~")
npx_path = "$(which npx 2>/dev/null || echo "npx")"
force = $([[ "$FORCE" == "true" ]] && echo "True" || echo "False")

# Load or create target config
if os.path.exists(target_path):
    with open(target_path) as f:
        config = json.load(f)
else:
    config = {}

if "mcpServers" not in config:
    config["mcpServers"] = {}

with open(template_path) as f:
    template = json.load(f)

servers = template.get("mcpServers", {})
added = []
updated = []
skipped = []

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
        continue

    action = "updated" if name in config["mcpServers"] else "added"
    config["mcpServers"][name] = cfg
    (updated if action == "updated" else added).append(name)

with open(target_path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

if added:
    print(f"  Added:   {', '.join(added)}")
if updated:
    print(f"  Updated: {', '.join(updated)}")
if skipped:
    print(f"  Skipped (exists, use --force): {', '.join(skipped)}")

total = list(config["mcpServers"].keys())
print(f"Total MCP servers: {len(total)} — {total}")
PYEOF

success "MCP servers applied to Copilot CLI config ($TARGET)"
echo ""
echo "  Launch Copilot:  ollama launch copilot"
echo "  Or directly:     copilot"
echo ""
