#!/bin/bash
# =============================================================================
# disable-zscaler.sh — Disable Zscaler proxy (macOS)
# =============================================================================
# Unloads the Zscaler LaunchDaemon services that intercept HTTPS traffic.
# The system daemons require sudo; the user-level tray does not.
#
# Why this matters for AI agents:
#   Zscaler intercepts long-running HTTPS streams to Ollama cloud endpoints
#   (34.36.133.15:443), dropping connections mid-stream. This kills subagents
#   mid-generation — especially tasks longer than ~5 minutes.
#
# Usage:
#   scripts/disable-zscaler.sh          # unload all (requires sudo)
#   scripts/disable-zscaler.sh --check  # check current status only
#   scripts/disable-zscaler.sh --tray   # unload tray only (no sudo needed)
# =============================================================================

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()     { echo -e "${BLUE}[ZSCALER]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

DAEMON_SERVICE="/Library/LaunchDaemons/com.zscaler.service.plist"
DAEMON_TUNNEL="/Library/LaunchDaemons/com.zscaler.tunnel.plist"
AGENT_TRAY="/Library/LaunchAgents/com.zscaler.tray.plist"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   Zscaler Disable                    ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Check current status
check_status() {
    local running=false
    launchctl list | grep -q "zscaler" && running=true
    local proxy_http
    proxy_http=$(scutil --proxy 2>/dev/null | grep "HTTPEnable" | awk '{print $3}')
    
    if $running; then
        warn "Zscaler tray: RUNNING"
    else
        success "Zscaler tray: not running"
    fi

    if [ -f "$DAEMON_SERVICE" ]; then
        warn "Service daemon: installed at $DAEMON_SERVICE"
    else
        success "Service daemon: not installed"
    fi

    if [ -f "$DAEMON_TUNNEL" ]; then
        warn "Tunnel daemon: installed at $DAEMON_TUNNEL"
    else
        success "Tunnel daemon: not installed"
    fi

    echo ""
    echo "HTTP proxy enabled: ${proxy_http:-unknown}"
    echo "HTTPS proxy enabled: $(scutil --proxy 2>/dev/null | grep 'HTTPSEnable' | awk '{print $3}')"
    echo ""

    # Quick connectivity test
    log "Testing direct connectivity to ollama.com..."
    if curl -s --max-time 5 -o /dev/null -w "%{http_code}" https://ollama.com 2>/dev/null | grep -q "200\|301\|302"; then
        success "ollama.com reachable directly (Zscaler not intercepting)"
    else
        warn "ollama.com not reachable or being intercepted"
    fi
}

if [[ "$*" == *"--check"* ]]; then
    check_status
    exit 0
fi

# Unload tray (no sudo needed)
if launchctl list | grep -q "zscaler"; then
    log "Unloading Zscaler tray..."
    launchctl unload "$AGENT_TRAY" 2>/dev/null && success "Tray unloaded" || warn "Tray unload failed (may already be unloaded)"
else
    success "Tray already not running"
fi

if [[ "$*" == *"--tray"* ]]; then
    check_status
    exit 0
fi

# Unload system daemons (requires sudo)
if [ -f "$DAEMON_SERVICE" ] || [ -f "$DAEMON_TUNNEL" ]; then
    echo ""
    warn "System daemons require sudo. Run these commands in your terminal:"
    echo ""
    echo "  sudo launchctl unload $DAEMON_SERVICE"
    echo "  sudo launchctl unload $DAEMON_TUNNEL"
    echo ""
    warn "Note: These daemons restart on boot unless also disabled:"
    echo "  sudo launchctl disable system/com.zscaler.service"
    echo "  sudo launchctl disable system/com.zscaler.tunnel"
    echo ""
    
    # Try with sudo if available
    if sudo -n true 2>/dev/null; then
        log "sudo available — unloading daemons..."
        sudo launchctl unload "$DAEMON_SERVICE" 2>/dev/null && success "Service daemon unloaded" || warn "Service daemon already unloaded"
        sudo launchctl unload "$DAEMON_TUNNEL" 2>/dev/null && success "Tunnel daemon unloaded" || warn "Tunnel daemon already unloaded"
    fi
else
    success "No system daemons found"
fi

echo ""
check_status
