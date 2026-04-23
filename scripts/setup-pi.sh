#!/bin/bash
# =============================================================================
# setup-pi.sh — Configure Pi agent for Ollama backend
# =============================================================================
# Applies configs/pi-settings.json to ~/.pi/agent/settings.json.
# Installs pi-subagents and pi-autoresearch packages.
#
# Usage:
#   scripts/setup-pi.sh [--model MODEL_NAME]
#   --model : override the Ollama model (default: qwen3:32b)
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_DIR/configs/pi-settings.json"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()     { echo -e "${BLUE}[PI]${NC} $1"; }
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
echo "║   Pi Agent Setup                     ║"
echo "╚══════════════════════════════════════╝"
echo ""

command -v python3 >/dev/null 2>&1 || error "python3 not found"
[ -f "$TEMPLATE" ] || error "Template not found: $TEMPLATE"

if [ ! -d "$HOME/.pi/agent" ]; then
    warn "~/.pi/agent not found. Install Pi first."
    warn "Then re-run this script."
    exit 0
fi

TARGET="$HOME/.pi/agent/settings.json"

# Backup
if [ -f "$TARGET" ]; then
    BACKUP="$TARGET.bak_setup_$(date +%Y%m%d_%H%M%S)"
    cp "$TARGET" "$BACKUP"
    success "Backup: $BACKUP"
fi

# Apply template with substitutions
python3 << PYEOF
import json, os

template_path = "$TEMPLATE"
target_path = "$TARGET"
model = "$OLLAMA_MODEL"
home = os.path.expanduser("~")

with open(template_path) as f:
    settings = json.load(f)

# Remove comment keys (start with _)
settings = {k: v for k, v in settings.items() if not k.startswith("_")}

# Substitute placeholders
settings["defaultModel"] = model
if "skillsDir" in settings:
    settings["skillsDir"] = settings["skillsDir"].replace("{{HOME}}", home)

# Preserve lastChangelogVersion if exists
try:
    with open(target_path) as f:
        existing = json.load(f)
    if "lastChangelogVersion" in existing:
        settings["lastChangelogVersion"] = existing["lastChangelogVersion"]
except:
    pass

with open(target_path, "w") as f:
    json.dump(settings, f, indent=2)

print(f"Model: {model}")
print(f"Provider: {settings['defaultProvider']}")
print(f"Packages: {settings['packages']}")
print(f"Skills dir: {settings.get('skillsDir', 'not set')}")
PYEOF

# Ensure skills directory exists
if [ -n "$(python3 -c "import json; print(json.load(open('$TARGET')).get('skillsDir',''))")" ]; then
    PI_SKILLS_DIR="$(python3 -c "import json,os; d=json.load(open('$TARGET')).get('skillsDir',''); print(d)")"
    mkdir -p "$PI_SKILLS_DIR"
    success "Skills directory created: $PI_SKILLS_DIR"
fi

success "Pi settings applied: $TARGET"
echo ""
log "Start Pi with: pi  (or: ollama launch pi)"
echo ""