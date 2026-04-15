#!/bin/bash
# =============================================================================
# verify.sh — Verify the full agent harness setup is working
# =============================================================================
# Checks all components: Ollama, Claude Code MCP, OpenClaw, Pi, Codex,
# skills layer, and network/proxy status.
#
# Usage:
#   scripts/verify.sh [--fix]
#   --fix : attempt to auto-fix issues found
# =============================================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Platform detection
case "$(uname -s)" in
    Darwin*)                 OS_TYPE="macOS" ;;
    Linux*)                  OS_TYPE="Linux" ;;
    MINGW*|MSYS*|CYGWIN*)   OS_TYPE="Windows" ;;
    *)                       OS_TYPE="Unknown" ;;
esac

# Detect user's default shell
case "${SHELL##*/}" in
    zsh)  USER_SHELL="zsh";  PRIMARY_RC="$HOME/.zshrc" ;;
    bash) USER_SHELL="bash"; PRIMARY_RC="$HOME/.bashrc" ;;
    *)    USER_SHELL="bash"; PRIMARY_RC="$HOME/.bashrc" ;;
esac

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; WARN_COUNT=$((WARN_COUNT+1)); }
section() { echo ""; echo -e "${CYAN}── $1 ──${NC}"; }

FAIL_COUNT=0; WARN_COUNT=0
FIX=false
[[ "$*" == *"--fix"* ]] && FIX=true

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   Agent Harness Verification         ║"
echo "╚══════════════════════════════════════╝"

# ── Ollama ──
section "Ollama"
if command -v ollama >/dev/null 2>&1; then
    ok "ollama binary found: $(command -v ollama)"
else
    fail "ollama not found — install from https://ollama.com"
fi

if curl -s --max-time 3 http://localhost:11434/api/status >/dev/null 2>&1; then
    ok "Ollama server running (localhost:11434)"
    MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ' ')
    ok "Models: $MODELS"
else
    fail "Ollama server not running — start it: ollama serve"
fi

# Check config
if [ -f "$HOME/.ollama/config.json" ]; then
    ok "~/.ollama/config.json present"
    LAST_SEL=$(python3 -c "import json; d=json.load(open('$HOME/.ollama/config.json')); print(d.get('last_selection','?'))" 2>/dev/null)
    ok "  Last integration: $LAST_SEL"
else
    warn "~/.ollama/config.json not found"
fi

# ── Claude Code ──
section "Claude Code (ollama launch claude)"
if command -v claude >/dev/null 2>&1; then
    ok "claude binary found"
else
    fail "claude not found — install Claude Code"
fi

if [ -f "$HOME/.claude.json" ]; then
    ok "~/.claude.json present"
    MCP_COUNT=$(python3 -c "import json; d=json.load(open('$HOME/.claude.json')); print(len(d.get('mcpServers',{})))" 2>/dev/null)
    if [ "$MCP_COUNT" -gt 0 ] 2>/dev/null; then
        ok "MCP servers configured: $MCP_COUNT"
        MCP_NAMES=$(python3 -c "import json; d=json.load(open('$HOME/.claude.json')); print(' '.join(d.get('mcpServers',{}).keys()))" 2>/dev/null)
        ok "  Servers: $MCP_NAMES"
    else
        fail "No MCP servers configured in ~/.claude.json"
        if $FIX; then
            echo "    → Running setup-mcp.sh..."
            "$REPO_DIR/scripts/setup-mcp.sh" && ok "Fixed: MCP servers applied"
        else
            echo "    → Fix: scripts/setup-mcp.sh"
        fi
    fi
else
    fail "~/.claude.json not found — run Claude Code once to initialize"
fi

if [ -d "$HOME/.claude/skills-cache" ] && [ -f "$HOME/.claude/skills-cache/combined-skills.txt" ]; then
    SKILL_SIZE=$(wc -c < "$HOME/.claude/skills-cache/combined-skills.txt" | tr -d ' ')
    ok "Skills cache: $SKILL_SIZE bytes"
else
    warn "Skills cache missing — run: safe-install.sh"
fi

# ── OpenClaw ──
section "OpenClaw (ollama launch openclaw)"
if command -v openclaw >/dev/null 2>&1; then
    ok "openclaw binary found"
else
    warn "openclaw not found — install: ollama launch openclaw --config"
fi

if [ -f "$HOME/.openclaw/openclaw.json" ]; then
    ok "~/.openclaw/openclaw.json present"
    python3 << 'PYEOF'
import json, os
cfg = json.load(open(os.path.expanduser("~/.openclaw/openclaw.json")))
web_fetch = cfg.get("tools",{}).get("web",{}).get("fetch",{}).get("enabled", False)
web_search = cfg.get("tools",{}).get("web",{}).get("search",{}).get("enabled", False)
ollama_plugin = cfg.get("plugins",{}).get("entries",{}).get("ollama",{}).get("enabled", False)
model = cfg.get("agents",{}).get("defaults",{}).get("model",{}).get("primary","?")
gw_port = cfg.get("gateway",{}).get("port", "?")
print(f"  Model:         {model}")
print(f"  Web fetch:     {'✓ enabled' if web_fetch else '✗ disabled'}")
print(f"  Web search:    {'✓ enabled' if web_search else '✗ disabled'}")
print(f"  Ollama plugin: {'✓ enabled' if ollama_plugin else '✗ disabled'}")
print(f"  Gateway port:  {gw_port}")
PYEOF
else
    warn "~/.openclaw/openclaw.json not found"
    if $FIX; then
        echo "    → Running setup-openclaw.sh..."
        "$REPO_DIR/scripts/setup-openclaw.sh" && ok "Fixed: OpenClaw config applied"
    else
        echo "    → Fix: scripts/setup-openclaw.sh"
    fi
fi

# Check gateway running
if curl -s --max-time 2 http://localhost:18789/ 2>/dev/null | grep -q "OpenClaw"; then
    ok "OpenClaw gateway: running (port 18789)"
else
    warn "OpenClaw gateway not running (start: ollama launch openclaw)"
fi

# ── Pi ──
section "Pi (ollama launch pi)"
if command -v pi >/dev/null 2>&1; then
    ok "pi binary found"
else
    warn "pi not found — install Pi agent"
fi

if [ -f "$HOME/.pi/agent/settings.json" ]; then
    ok "~/.pi/agent/settings.json present"
    python3 << 'PYEOF'
import json, os
s = json.load(open(os.path.expanduser("~/.pi/agent/settings.json")))
print(f"  Model:    {s.get('defaultModel','?')}")
print(f"  Provider: {s.get('defaultProvider','?')}")
print(f"  Packages: {s.get('packages',[])}")
PYEOF
    SKILL_COUNT=$(ls "$HOME/.pi/agent/skills/" 2>/dev/null | wc -l | tr -d ' ')
    ok "Pi skills directory: $SKILL_COUNT skills linked"
else
    warn "~/.pi/agent/settings.json not found"
fi

# ── Codex ──
section "Codex (ollama launch codex)"
if command -v codex >/dev/null 2>&1; then
    ok "codex binary found"
else
    warn "codex not found — install Codex CLI"
fi

if [ -f "$HOME/.codex/config.toml" ]; then
    ok "~/.codex/config.toml present"
    PROVIDER=$(grep "model_provider" "$HOME/.codex/config.toml" | head -1 | cut -d'"' -f2)
    MODEL=$(grep "^model = " "$HOME/.codex/config.toml" | cut -d'"' -f2)
    ok "  Provider: $PROVIDER | Model: $MODEL"
else
    warn "~/.codex/config.toml not found"
fi

# ── Skills Layer ──
section "Shell Skills Layer"

# Check all possible RC files, but primary is based on user's shell
skills_found=false
for rc_file in "$PRIMARY_RC" "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if [ -f "$rc_file" ] && grep -q "_claude_with_skills\|# Skills Layer" "$rc_file" 2>/dev/null; then
        ok "Skills layer in $rc_file"
        skills_found=true
    fi
done
if ! $skills_found; then
    fail "Skills layer not installed in any shell rc file"
    if $FIX; then
        echo "    → Running safe-install.sh..."
        "$REPO_DIR/safe-install.sh" && ok "Fixed: Skills layer installed"
    else
        echo "    → Fix: ./safe-install.sh"
    fi
fi

# Check aliases in the primary rc file
for alias_name in claude openclaw codex ollama pi; do
    if grep -q "alias $alias_name=" "$PRIMARY_RC" 2>/dev/null; then
        ok "alias '$alias_name' configured in $(basename "$PRIMARY_RC")"
    elif grep -q "alias $alias_name=" "$HOME/.zshrc" "$HOME/.bashrc" 2>/dev/null; then
        ok "alias '$alias_name' configured (in alternate rc)"
    else
        warn "alias '$alias_name' not found in shell rc files"
    fi
done

# ── Network / Proxy ──
section "Network & Proxy"

if [ "$OS_TYPE" = "macOS" ]; then
    PROXY_HTTP=$(scutil --proxy 2>/dev/null | grep "HTTPEnable" | awk '{print $3}')
    PROXY_HTTPS=$(scutil --proxy 2>/dev/null | grep "HTTPSEnable" | awk '{print $3}')

    if [ "$PROXY_HTTP" = "1" ] || [ "$PROXY_HTTPS" = "1" ]; then
        warn "System HTTP/HTTPS proxy is ENABLED — may intercept Ollama streams"
        echo "    → Fix: scripts/disable-zscaler.sh"
    else
        ok "No system HTTP/HTTPS proxy (Zscaler off)"
    fi

    if launchctl list 2>/dev/null | grep -q "zscaler"; then
        warn "Zscaler tray still running"
        echo "    → Fix: scripts/disable-zscaler.sh --tray"
    else
        ok "Zscaler tray: not running"
    fi
else
    # Linux/Windows: check environment proxy variables
    if [ -n "$http_proxy" ] || [ -n "$https_proxy" ] || [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
        warn "HTTP proxy env vars set — may intercept Ollama streams"
        [ -n "$http_proxy" ] && echo "    http_proxy=$http_proxy"
        [ -n "$https_proxy" ] && echo "    https_proxy=$https_proxy"
    else
        ok "No proxy env vars set"
    fi
fi

if curl -s --max-time 5 -o /dev/null -w "%{http_code}" https://ollama.com 2>/dev/null | grep -q "200\|301\|302"; then
    ok "ollama.com reachable"
else
    warn "ollama.com not reachable — cloud models may fail"
fi

# ── Summary ──
echo ""
echo "════════════════════════════════════════"
if [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
elif [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${YELLOW}✓ Passed with $WARN_COUNT warning(s) — review above${NC}"
else
    echo -e "${RED}✗ $FAIL_COUNT failure(s), $WARN_COUNT warning(s) — run with --fix or check above${NC}"
fi
echo ""
