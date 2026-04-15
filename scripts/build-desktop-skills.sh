#!/bin/bash
# =============================================================================
# build-desktop-skills.sh — Install skills into Claude Desktop app
# =============================================================================
# Writes individual SKILL.md files into the Claude Desktop skills-plugin
# directory AND registers them in manifest.json so the app loads them.
#
# Cross-platform:
#   macOS:   ~/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/
#   Linux:   ~/.config/Claude/local-agent-mode-sessions/skills-plugin/  (expected)
#   Windows: %APPDATA%\Claude\local-agent-mode-sessions\skills-plugin\  (expected)
#
# Tiers:
#   essential  — Personal learned skills only
#   standard   — + All universal agents + top commands
#   full       — + ALL universal commands (default)
#
# Usage:
#   scripts/build-desktop-skills.sh                   # Full tier (default)
#   scripts/build-desktop-skills.sh --tier essential
#   scripts/build-desktop-skills.sh --tier standard
#   scripts/build-desktop-skills.sh --tier full
# =============================================================================
set -e

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()     { echo -e "${BLUE}[SKILLS]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }

LEARNED_DIR="$HOME/.claude/skills/learned"
AGENTS_DIR="$HOME/.claude-everything-claude-code/agents"
COMMANDS_DIR="$HOME/.claude-everything-claude-code/commands"

TIER="full"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tier) TIER="$2"; shift 2 ;;
        *) shift ;;
    esac
done

log "Tier: $TIER"

# =============================================================================
# Detect Desktop skills directory + manifest
# =============================================================================
detect_skills_dir() {
    local base=""
    case "$(uname -s)" in
        Darwin*)  base="$HOME/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin" ;;
        Linux*)   base="$HOME/.config/Claude/local-agent-mode-sessions/skills-plugin" ;;
        MINGW*|MSYS*|CYGWIN*)
            if [ -n "$APPDATA" ]; then
                base="$APPDATA/Claude/local-agent-mode-sessions/skills-plugin"
            else
                base="$HOME/AppData/Roaming/Claude/local-agent-mode-sessions/skills-plugin"
            fi
            ;;
    esac

    if [ ! -d "$base" ]; then
        warn "Skills-plugin directory not found: $base"
        warn "Open Claude Desktop at least once, then re-run."
        return 1
    fi

    # Find the most recent session with a manifest.json
    local latest_org=""
    local latest_time=0
    for session_dir in "$base"/*/; do
        [ -d "$session_dir" ] || continue
        for org_dir in "$session_dir"*/; do
            [ -f "$org_dir/manifest.json" ] || continue
            local mtime
            mtime=$(stat -f %m "$org_dir/manifest.json" 2>/dev/null || stat -c %Y "$org_dir/manifest.json" 2>/dev/null || echo 0)
            if [ "$mtime" -gt "$latest_time" ]; then
                latest_time=$mtime
                latest_org="$org_dir"
            fi
        done
    done

    if [ -z "$latest_org" ]; then
        warn "No active skills session with manifest.json found in $base"
        return 1
    fi

    DESKTOP_SKILLS_DIR="${latest_org}skills"
    DESKTOP_MANIFEST="${latest_org}manifest.json"
    mkdir -p "$DESKTOP_SKILLS_DIR"
    log "Skills dir: $DESKTOP_SKILLS_DIR"
    log "Manifest:   $DESKTOP_MANIFEST"
}

detect_skills_dir || exit 1

# =============================================================================
# Skill lists
# =============================================================================
UNIVERSAL_AGENTS=(
    performance-optimizer code-reviewer typescript-reviewer planner
    a11y-architect architect chief-of-staff security-reviewer
    database-reviewer e2e-runner build-error-resolver docs-lookup
    python-reviewer doc-updater tdd-guide refactor-cleaner
    seo-specialist code-explorer code-architect conversation-analyzer
    code-simplifier comment-analyzer silent-failure-hunter
    pr-test-analyzer harness-optimizer loop-operator type-design-analyzer
)

TOP_COMMANDS=(
    code-review tdd e2e build-fix feature-dev plan checkpoint
    review-pr refactor-clean test-coverage docs eval verify
    quality-gate context-budget model-route update-docs python-review
    prp-prd prp-plan prp-implement prp-pr prp-commit
)

ALL_UNIVERSAL_COMMANDS=(
    code-review tdd e2e build-fix feature-dev plan checkpoint review-pr
    refactor-clean test-coverage docs eval verify quality-gate context-budget
    model-route update-docs python-review prp-prd prp-plan prp-implement
    prp-pr prp-commit sessions save-session resume-session multi-execute
    multi-plan multi-workflow multi-frontend multi-backend santa-loop aside
    skill-create evolve skill-health orchestrate learn-eval pm2 jira
    instinct-import instinct-export instinct-status learn setup-pm promote
    hookify hookify-help hookify-configure hookify-list update-codemaps
    harness-audit loop-start loop-status projects devfleet prune
    prompt-optimize rules-distill agent-sort claw
)

# =============================================================================
# Collect skills to install, then write files + update manifest in one pass
# =============================================================================
# Build a list of (skill_id, source_file) pairs
SKILL_LIST=()

# --- Personal learned skills (always) ---
if [ -d "$LEARNED_DIR" ]; then
    for f in "$LEARNED_DIR"/*.md; do
        [ -f "$f" ] || continue
        name=$(basename "$f" .md)
        SKILL_LIST+=("learned-$name|$f")
    done
fi

# --- Universal agents (standard + full) ---
if [ "$TIER" = "standard" ] || [ "$TIER" = "full" ]; then
    for name in "${UNIVERSAL_AGENTS[@]}"; do
        f="$AGENTS_DIR/$name.md"
        [ -f "$f" ] && SKILL_LIST+=("agent-$name|$f")
    done
fi

# --- Commands ---
if [ "$TIER" = "standard" ]; then
    for name in "${TOP_COMMANDS[@]}"; do
        f="$COMMANDS_DIR/$name.md"
        [ -f "$f" ] && SKILL_LIST+=("cmd-$name|$f")
    done
elif [ "$TIER" = "full" ]; then
    SEEN_FILE=$(mktemp)
    trap "rm -f $SEEN_FILE" EXIT
    for name in "${ALL_UNIVERSAL_COMMANDS[@]}"; do
        if ! grep -qx "$name" "$SEEN_FILE" 2>/dev/null; then
            echo "$name" >> "$SEEN_FILE"
            f="$COMMANDS_DIR/$name.md"
            [ -f "$f" ] && SKILL_LIST+=("cmd-$name|$f")
        fi
    done
    rm -f "$SEEN_FILE"
fi

log "Collected ${#SKILL_LIST[@]} skills to install"

# =============================================================================
# Write skill files to disk + register in manifest.json
# =============================================================================
python3 << PYEOF
import json, os, re, shutil

skills_dir = """$DESKTOP_SKILLS_DIR"""
manifest_path = """$DESKTOP_MANIFEST"""

# Parse skill list from bash
skill_entries = """$(IFS=$'\n'; echo "${SKILL_LIST[*]}")""".strip().split('\n')
skill_entries = [s for s in skill_entries if '|' in s]

# Load manifest
with open(manifest_path) as f:
    manifest = json.load(f)

existing_ids = {s['skillId'] for s in manifest['skills']}
installed = 0

for entry in skill_entries:
    skill_id, source_file = entry.split('|', 1)

    if not os.path.isfile(source_file):
        continue

    # Read source
    with open(source_file) as f:
        content = f.read()

    # Extract description from YAML frontmatter or first non-empty line
    desc = ""
    if content.startswith("---"):
        parts = content.split("---", 2)
        if len(parts) >= 3:
            fm = parts[1]
            # Try to get description from frontmatter
            m = re.search(r'^description:\s*["\']?(.+?)["\']?\s*$', fm, re.MULTILINE)
            if m:
                desc = m.group(1)[:300]
            # If block scalar, get next lines
            elif re.search(r'^description:\s*[>|]', fm, re.MULTILINE):
                lines = fm.split('\n')
                block = []
                capture = False
                for line in lines:
                    if line.strip().startswith('description:'):
                        capture = True
                        continue
                    if capture:
                        if line.startswith('  ') or line.startswith('\t'):
                            block.append(line.strip())
                        else:
                            break
                desc = ' '.join(block)[:300]

    if not desc:
        # Fallback: first non-header, non-empty line
        for line in content.split('\n'):
            line = line.strip()
            if line and not line.startswith('#') and not line.startswith('---'):
                desc = line[:300]
                break

    # Ensure SKILL.md has frontmatter
    if content.startswith("---"):
        skill_content = content
    else:
        skill_content = f'---\nname: {skill_id}\ndescription: "{desc}"\n---\n\n{content}'

    # Write SKILL.md
    skill_path = os.path.join(skills_dir, skill_id)
    os.makedirs(skill_path, exist_ok=True)
    with open(os.path.join(skill_path, 'SKILL.md'), 'w') as f:
        f.write(skill_content)

    # Register in manifest if not already there
    if skill_id not in existing_ids:
        manifest['skills'].append({
            'skillId': skill_id,
            'name': skill_id,
            'description': desc.replace('"', "'"),
            'creatorType': 'user',
            'updatedAt': None,
            'enabled': True
        })
        existing_ids.add(skill_id)

    installed += 1

# Write updated manifest
with open(manifest_path, 'w') as f:
    json.dump(manifest, f, indent=2)

print(f"Installed {installed} skills to disk + manifest ({len(manifest['skills'])} total in manifest)")
PYEOF

success "Skills installed into Claude Desktop (tier: $TIER)"
success "Path: $DESKTOP_SKILLS_DIR"
log "Restart Claude Desktop to load new skills."
