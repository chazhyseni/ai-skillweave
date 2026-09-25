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
# Skills approach:
#   1. Agent-mode sessions: Desktop reads ~/.claude/skills/ natively for / slash commands.
#   2. Customize → Capabilities panel: Reads from the skills-plugin/ directory + manifest.json.
#   This script injects skills into BOTH paths — symlinks in the skills-plugin dir and
#   manifest.json entries — so skills appear in the Customize panel AND work via / commands.
#
# Usage:
#   ./scripts/setup-claude-desktop.sh                    # Full setup (MCP + inject skills)
#   ./scripts/setup-claude-desktop.sh --mcp-only         # MCP servers only
#   ./scripts/setup-claude-desktop.sh --skills-only      # Inject skills only (no MCP)
#   ./scripts/setup-claude-desktop.sh --package-skills   # Build .skill files for manual upload
#   ./scripts/setup-claude-desktop.sh --tier essential    # Minimal skills (~6K tokens)
#   ./scripts/setup-claude-desktop.sh --tier standard     # Agents + top commands (~54K tokens)
#   ./scripts/setup-claude-desktop.sh --tier full         # All universal skills (~89K tokens, default)
#   ./scripts/setup-claude-desktop.sh --force             # Overwrite existing skills + MCP entries
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
PACKAGE_SKILLS=false
TIER="full"
CLEAN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)          FORCE=true; shift ;;
        --mcp-only)       MCP_ONLY=true; shift ;;
        --skills-only)    SKILLS_ONLY=true; shift ;;
        --package-skills)  PACKAGE_SKILLS=true; shift ;;
        --tier)
            [ "$#" -ge 2 ] && [[ "$2" != --* ]] || error '--tier requires essential|standard|full'
            TIER="$2"; shift 2 ;;
        --clean)          CLEAN=true; shift ;;
        --help|-h)
            echo "Usage: setup-claude-desktop.sh [--mcp-only] [--skills-only] [--package-skills]"
            echo "       [--tier essential|standard|full] [--force] [--clean]"
            echo ""
            echo "  --package-skills  Build .skill files for manual upload (default: inject into Desktop)"
            echo "  Without --package-skills, skills are symlinked from ~/.claude/skills/ into Desktop"
            echo "  --force           Overwrite existing skill directories and MCP entries"
            exit 0
            ;;
        *) error "Unknown option: $1" ;;
    esac
done
case "$TIER" in essential|standard|full) ;; *) error "Unknown tier: $TIER" ;; esac
if $MCP_ONLY && $SKILLS_ONLY; then error '--mcp-only and --skills-only are mutually exclusive'; fi

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

    local args=()
    if $FORCE; then args+=(--force); fi
    python3 "$REPO_DIR/scripts/merge-mcp-config.py" "$TEMPLATE" "$DESKTOP_CONFIG" --desktop "${args[@]}" || return 1

    success "MCP servers applied to Claude Desktop config"
    echo ""
    log "Restart Claude Desktop for changes to take effect."
}

# =============================================================================
# Part 2: Skills injection into Desktop's Customize → Capabilities panel
# =============================================================================
link_skills() {
    # Claude Desktop has two skill discovery mechanisms:
    #   1. Agent-mode / slash commands: reads ~/.claude/skills/ natively (always works)
    #   2. Customize → Capabilities panel: reads from skills-plugin/<session>/<project>/skills/ + manifest.json
    # This function injects skills into BOTH paths by:
    #   - Creating symlinks from Desktop's skills dir → ~/.claude/skills/ entries
    #   - Updating manifest.json to register all injected skills
    # This makes skills appear in the Customize panel AND work via / commands.

    local skills_dir="$HOME/.claude/skills"

    if [ ! -d "$skills_dir" ]; then
        warn "~/.claude/skills/ not found — run safe-install.sh first"
        return 1
    fi

    local count=$(find "$skills_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -eq 0 ]; then
        warn "No skills found in ~/.claude/skills/ — run safe-install.sh first"
        return 1
    fi

    success "Found $count skills in ~/.claude/skills/"

    # Determine Desktop's skills-plugin base path
    local desktop_base
    case "$(uname -s)" in
        Darwin*)  desktop_base="$HOME/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin" ;;
        Linux*)   desktop_base="$HOME/.config/Claude/local-agent-mode-sessions/skills-plugin" ;;
        *)        warn "Unsupported OS for Desktop skill injection"; return 1 ;;
    esac

    if [ ! -d "$desktop_base" ]; then
        warn "Desktop skills-plugin directory not found: $desktop_base"
        log "Open Claude Desktop once to create it, then re-run."
        log "Skills will still work via / slash commands in agent-mode sessions."
        return 1
    fi

    # Find all session directories that contain manifest.json
    local session_dirs=()
    while IFS= read -r manifest; do
        # manifest path: <base>/<session-uuid>/<project-uuid>/manifest.json
        local session_dir
        session_dir="$(dirname "$manifest")"
        session_dirs+=("$session_dir")
    done < <(find "$desktop_base" -name "manifest.json" 2>/dev/null)

    if [ ${#session_dirs[@]} -eq 0 ]; then
        warn "No Desktop session found — open Claude Desktop and add at least one skill, then re-run."
        log "Skills will still work via / slash commands in agent-mode sessions."
        return 1
    fi

    log "Found ${#session_dirs[@]} Desktop session(s) to inject skills into"

    local total_injected=0
    local total_updated=0

    for session_dir in "${session_dirs[@]}"; do
        local manifest="$session_dir/manifest.json"
        local desk_skills_dir="$session_dir/skills"

        if [ ! -f "$manifest" ]; then
            warn "No manifest.json in $session_dir — skipping"
            continue
        fi

        mkdir -p "$desk_skills_dir"

        # Backup manifest
        cp "$manifest" "${manifest}.bak_$(date +%Y%m%d_%H%M%S)"

        local injected=0
        local skipped=0

        # Iterate over each skill in ~/.claude/skills/
        while IFS= read -r skill_path; do
            [ -d "$skill_path" ] || continue
            local skill_name
            skill_name="$(basename "$skill_path")"

            # Skip the 'learned' directory (handled separately)
            if [ "$skill_name" = "learned" ]; then
                # Learned skills are individual .md files, not SKILL.md dirs
                continue
            fi

            # Check for SKILL.md
            if [ ! -f "$skill_path/SKILL.md" ]; then
                # Try .md file with same name (some skills are just .md files)
                if [ -f "$skill_path/$skill_name.md" ]; then
                    : # will be handled below
                else
                    continue
                fi
            fi

            local dest="$desk_skills_dir/$skill_name"

            if [ -L "$dest" ]; then
                # Update existing symlink
                rm "$dest"
                ln -s "$skill_path" "$dest"
                skipped=$((skipped + 1))
            elif [ -d "$dest" ] && [ "$FORCE" = true ]; then
                # Overwrite real directory with symlink
                rm -rf "$dest"
                ln -s "$skill_path" "$dest"
                total_updated=$((total_updated + 1))
            elif [ -d "$dest" ]; then
                # Skip — skill already exists as real directory (from Desktop UI)
                skipped=$((skipped + 1))
            else
                # New skill — create symlink
                ln -s "$skill_path" "$dest"
                injected=$((injected + 1))
            fi
        done < <(find "$skills_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

        # Also handle learned skills (individual .md files in ~/.claude/skills/learned/)
        local learned_dir="$skills_dir/learned"
        if [ -d "$learned_dir" ]; then
            while IFS= read -r md_file; do
                [ -f "$md_file" ] || continue
                local skill_name
                skill_name="learned-$(basename "$md_file" .md)"
                local dest="$desk_skills_dir/$skill_name"

                if [ -L "$dest" ] || [ -d "$dest" ]; then
                    skipped=$((skipped + 1))
                    continue
                fi

                # Create a temporary directory with SKILL.md for learned skills
                mkdir -p "$dest"
                cp "$md_file" "$dest/SKILL.md"
                injected=$((injected + 1))
            done < <(find "$learned_dir" -maxdepth 1 -name "*.md" 2>/dev/null)
        fi

        # Update manifest.json to include all injected skills
        python3 << PYEOF
import json, os, subprocess
from datetime import datetime, timezone

manifest_path = "$manifest"
skills_dir = "$desk_skills_dir"
force = $([[ "$FORCE" == "true" ]] && echo "True" || echo "False")

try:
    with open(manifest_path) as f:
        manifest = json.load(f)
except Exception:
    manifest = {"lastUpdated": 0, "skills": []}

existing_ids = {s['skillId'] for s in manifest.get('skills', [])}
now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.') + f'{datetime.now().microsecond // 1000:03d}Z'
added = 0

# Scan skills directory for entries not yet in manifest
for entry in sorted(os.listdir(skills_dir)):
    skill_md = os.path.join(skills_dir, entry, 'SKILL.md')
    # Also check if it's a symlink target
    entry_path = os.path.join(skills_dir, entry)
    if not os.path.isdir(entry_path):
        continue
    if not os.path.exists(skill_md):
        continue
    if entry in existing_ids and not force:
        continue

    # Extract description from SKILL.md YAML frontmatter
    desc = entry
    try:
        with open(skill_md) as f:
            content = f.read(2000)
        in_front = False
        for line in content.split('\n'):
            if line.strip() == '---':
                if in_front:
                    break
                in_front = True
                continue
            if in_front and line.startswith('description:'):
                desc = line.split(':', 1)[1].strip().strip('"').strip("'")[:500]
                break
    except Exception:
        pass

    skill_entry = {
        'skillId': entry,
        'name': entry,
        'description': desc,
        'creatorType': 'custom',
        'updatedAt': now,
        'enabled': True
    }

    if entry in existing_ids:
        # Update existing entry
        for i, s in enumerate(manifest['skills']):
            if s['skillId'] == entry:
                manifest['skills'][i] = skill_entry
                break
    else:
        manifest['skills'].append(skill_entry)
        added += 1

manifest['lastUpdated'] = int(datetime.now().timestamp() * 1000)

with open(manifest_path, 'w') as f:
    json.dump(manifest, f, indent=2)

total = len(manifest['skills'])
print(f'{added} new skills added, {total} total in manifest')
PYEOF

        total_injected=$((total_injected + injected))
        log "Session $(basename "$(dirname "$session_dir")"): $injected new symlinks, $skipped already present"
    done

    success "Injected $total_injected skills into Desktop ($total_updated updated)"
    log "Skills available via / slash commands (agent-mode) AND Customize → Capabilities panel"
    log "Restart Claude Desktop for changes to appear in the Customize panel"
}

# =============================================================================
# Part 2b: Package skills as .skill files (for manual upload fallback)
# =============================================================================
build_skills() {
    log "Building curated skills (tier: $TIER)..."
    CLEAN_FLAG=""
    $CLEAN && CLEAN_FLAG="--clean"
    bash "$REPO_DIR/scripts/build-desktop-skills.sh" --tier "$TIER" $CLEAN_FLAG
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
    if $PACKAGE_SKILLS; then
        echo ""
        log "Packaging .skill files for manual upload..."
        echo ""
        build_skills
    else
        echo ""
        log "Injecting skills from ~/.claude/skills/ into Desktop sessions..."
        echo ""
        echo ""
        link_skills
    fi
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Claude Desktop Setup Complete                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  Next steps:"
echo "    1. Restart Claude Desktop app"
echo "    2. MCP servers will appear in Claude Desktop settings"
echo "    3. Skills will appear in Customize → Capabilities panel"
echo ""
if $PACKAGE_SKILLS; then
echo "  Manual skill upload (only needed if / commands don't work):"
echo "    1. Open Claude Desktop → Customize → Skills"
echo "    2. Click '+' → 'Upload a skill'"
echo "    3. Select files from: $REPO_DIR/configs/desktop-skills"
echo ""
echo "  Or select all at once: open \"$REPO_DIR/configs/desktop-skills\""
echo ""
fi
echo "  Token economics:"
echo "    MCP servers: zero tokens until invoked"
echo "    Skills: symlinked from ~/.claude/skills/ into Desktop sessions"
echo "    Customize panel: populated via skills-plugin symlinks + manifest.json"
echo ""
echo "  Remote endpoints such as SkillGraph are not automatically registered."
echo "  Review privacy, authentication and current Desktop support before adding them."
echo ""
