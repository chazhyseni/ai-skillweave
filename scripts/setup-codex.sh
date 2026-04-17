#!/bin/bash
# =============================================================================
# setup-codex.sh — Configure Codex CLI for Ollama backend
# =============================================================================
# Applies configs/codex-config.toml to ~/.codex/config.toml.
# Configures the ollama-launch provider (OpenAI-compatible, localhost:11434/v1).
#
# Usage:
#   scripts/setup-codex.sh [--model MODEL_NAME]
#   --model : override the Ollama model (default: qwen3:32b)
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_DIR/configs/codex-config.toml"
TARGET="$HOME/.codex/config.toml"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()     { echo -e "${BLUE}[CODEX]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

OLLAMA_MODEL="qwen3:32b"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --model) OLLAMA_MODEL="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   Codex Setup                        ║"
echo "╚══════════════════════════════════════╝"
echo ""

[ -f "$TEMPLATE" ] || error "Template not found: $TEMPLATE"

if [ ! -d "$HOME/.codex" ]; then
    warn "~/.codex not found. Install Codex CLI first."
    warn "Then re-run this script."
    exit 0
fi

# Backup existing
if [ -f "$TARGET" ]; then
    BACKUP="$TARGET.bak_setup_$(date +%Y%m%d_%H%M%S)"
    cp "$TARGET" "$BACKUP"
    success "Backup: $BACKUP"
fi

# Substitute placeholders and write
sed \
    -e "s|{{OLLAMA_MODEL}}|$OLLAMA_MODEL|g" \
    -e "s|{{HOME}}|$HOME|g" \
    "$TEMPLATE" > "$TARGET"

success "Codex config applied: $TARGET"
log "Model: $OLLAMA_MODEL via ollama-launch provider"
log "Project trust: $HOME (trusted)"
echo ""
log "Start Codex with: codex  (or: ollama launch codex)"
echo ""
