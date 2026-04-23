#!/bin/bash
# =============================================================================
# setup-ollama-config.sh — Apply Ollama integration→model mapping
# =============================================================================
# Applies configs/ollama-integrations.json to ~/.ollama/config.json.
# Preserves last_selection and any other non-integrations keys.
# Safe to re-run (idempotent).
#
# Usage:
#   scripts/setup-ollama-config.sh
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_DIR/configs/ollama-integrations.json"
TARGET="$HOME/.ollama/config.json"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()     { echo -e "${BLUE}[OLLAMA]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   Ollama Integrations Setup          ║"
echo "╚══════════════════════════════════════╝"
echo ""

command -v python3 >/dev/null 2>&1 || error "python3 not found"
[ -f "$TEMPLATE" ] || error "Template not found: $TEMPLATE"

if [ ! -f "$TARGET" ]; then
    warn "~/.ollama/config.json not found — Ollama not configured yet"
    warn "Start Ollama first (open /Applications/Ollama.app), then re-run"
    exit 0
fi

# Backup
BACKUP="$TARGET.bak_setup_$(date +%Y%m%d_%H%M%S)"
cp "$TARGET" "$BACKUP"
success "Backup: $BACKUP"

python3 << PYEOF
import json, os

target_path = "$TARGET"
template_path = "$TEMPLATE"

with open(target_path) as f:
    config = json.load(f)

with open(template_path) as f:
    template = json.load(f)

# Only update the integrations key — preserve last_selection and other keys
new_integrations = template.get("integrations", {})

# Remove comment/metadata keys (start with _)
new_integrations = {k: v for k, v in new_integrations.items() if not k.startswith("_")}

old_integrations = config.get("integrations", {})
config["integrations"] = new_integrations

with open(target_path, "w") as f:
    json.dump(config, f, indent=2)

# Show what changed
for name, cfg in new_integrations.items():
    old_models = old_integrations.get(name, {}).get("models", [])
    new_models = cfg.get("models", [])
    if old_models != new_models:
        print(f"  Updated {name}: {old_models} → {new_models}")
    else:
        print(f"  Unchanged {name}: {new_models}")

print(f"\nlast_selection preserved: {config.get('last_selection','?')}")
PYEOF

success "Ollama integrations applied: $TARGET"
echo ""
log "Changes take effect on next Ollama launch."
echo ""
