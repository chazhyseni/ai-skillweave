#!/usr/bin/env bash
# desktop-batch-import.sh — Batch import .skill files into Claude Desktop
# Bypasses the 15-at-a-time UI limit by writing directly to Desktop's storage
#
# How it works:
#   Writes .skill files to the skills-plugin directory that the Customize panel
#   reads from. Claude Desktop MUST be closed before running this script, as the
#   app regenerates manifest.json on startup and will discard our changes if it
#   was running during the import.
#
# IMPORTANT: The Customize → Capabilities panel uses IndexedDB internally, but
#   the skills-plugin directory IS read for agent-mode skill discovery. Skills
#   imported here will appear in the Customize panel after restart, and are also
#   available via / slash commands in agent-mode sessions.
#
# For / slash commands ONLY (without Customize panel visibility), skills in
#   ~/.claude/skills/ (set up by safe-install.sh) are sufficient.
#
# Usage:
#   ./scripts/desktop-batch-import.sh                    # Import all skills
#   ./scripts/desktop-batch-import.sh --dry-run          # Show what would be imported
#   ./scripts/desktop-batch-import.sh --force            # Overwrite existing skills
#   ./scripts/desktop-batch-import.sh --clean            # Remove all custom skills first
#
# Prerequisites: Claude Desktop must be CLOSED before running this script.
# After import: restart Claude Desktop, skills appear in Customize → Capabilities.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="${REPO_DIR}/configs/desktop-skills"
DESKTOP_BASE="${HOME}/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin"

DRY_RUN=false
FORCE=false
CLEAN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --force)   FORCE=true ;;
        --clean)   CLEAN=true ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--force] [--clean]"
            echo ""
            echo "Batch import .skill files into Claude Desktop."
            echo "Close Claude Desktop before running, then restart after."
            echo ""
            echo "  --dry-run  Show what would be imported without making changes"
            echo "  --force    Overwrite skills that are already installed"
            echo "  --clean    Remove all custom skills before importing"
            exit 0
            ;;
    esac
done

# Find active session directory (the one with the most skills)
if [ ! -d "$DESKTOP_BASE" ]; then
    echo "ERROR: Claude Desktop skills directory not found at:"
    echo "  $DESKTOP_BASE"
    echo ""
    echo "Open Claude Desktop once to create the directory, then re-run."
    exit 1
fi

# Find session with the most skills (primary/active session)
SESSION_DIR=$(find "$DESKTOP_BASE" -name "manifest.json" -exec sh -c '
    count=$(python3 -c "import json; d=json.load(open(\"$1\")); print(len(d.get(\"skills\",[])))" "$1" 2>/dev/null || echo 0)
    echo "$count $1"
' _ {} \; 2>/dev/null | sort -rn | head -1 | sed 's/^[0-9]* //')

if [ -z "$SESSION_DIR" ]; then
    echo "ERROR: No active session found."
    echo "Open Claude Desktop, add at least one skill, then re-run."
    exit 1
fi

SESSION_DIR=$(dirname "$SESSION_DIR")  # manifest.json → session dir
SKILLS_DIR="${SESSION_DIR}/skills"
MANIFEST="${SESSION_DIR}/manifest.json"

echo "╔══════════════════════════════════════════════════════╗"
echo "║   Claude Desktop — Batch Skill Import                ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Session: $(basename "$(dirname "$SESSION_DIR")")"
echo "Skills dir: $SKILLS_DIR"
echo ""

# Count existing skills
EXISTING=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(len(d.get('skills',[])))" 2>/dev/null || echo 0)
echo "Currently installed: $EXISTING skills"

# Count source skills
TOTAL_SRC=$(ls "$SKILLS_SRC"/*.skill 2>/dev/null | wc -l | tr -d ' ')
echo "Available to import: $TOTAL_SRC skill files"
echo ""

# --clean: remove all custom (non-anthropic) skills first
if [ "$CLEAN" = true ] && [ "$DRY_RUN" = false ]; then
    BACKUP="${MANIFEST}.bak_clean_$(date +%Y%m%d_%H%M%S)"
    cp "$MANIFEST" "$BACKUP"
    echo "Backup: $BACKUP"

    python3 -c "
import json
manifest = json.load(open('$MANIFEST'))
before = len(manifest.get('skills', []))
manifest['skills'] = [s for s in manifest.get('skills', []) if s.get('creatorType') == 'anthropic']
manifest['lastUpdated'] = __import__('time').time() * 1000
with open('$MANIFEST', 'w') as f:
    json.dump(manifest, f, indent=2)
print(f'Cleaned: {before} -> {len(manifest[\"skills\"])} (kept anthropic skills)')
"

    # Remove custom skill directories
    python3 -c "
import json, os, shutil
manifest = json.load(open('$MANIFEST'))
keep = {s['skillId'] for s in manifest.get('skills', [])}
skills_dir = '$SKILLS_DIR'
removed = 0
for entry in os.listdir(skills_dir):
    path = os.path.join(skills_dir, entry)
    if os.path.isdir(path) and entry not in keep:
        shutil.rmtree(path)
        removed += 1
print(f'Removed {removed} custom skill directories')
"
    echo ""
fi

# Backup manifest (if not already backed up by --clean)
if [ "$DRY_RUN" = false ] && [ "$CLEAN" = false ]; then
    BACKUP="${MANIFEST}.bak_$(date +%Y%m%d_%H%M%S)"
    cp "$MANIFEST" "$BACKUP"
    echo "Backup: $BACKUP"
fi

# Import skills
IMPORTED=0
SKIPPED=0
UPDATED=0

for skill_file in "$SKILLS_SRC"/*.skill; do
    [ -f "$skill_file" ] || continue
    skill_name=$(basename "$skill_file" .skill)

    # Check if already installed
    if [ -d "${SKILLS_DIR}/${skill_name}" ] && [ "$FORCE" = false ]; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY] Would import: $skill_name"
        IMPORTED=$((IMPORTED + 1))
        continue
    fi

    # Unzip skill into destination (overwrites if exists)
    if [ -d "${SKILLS_DIR}/${skill_name}" ]; then
        rm -rf "${SKILLS_DIR}/${skill_name}"
        UPDATED=$((UPDATED + 1))
    fi

    if unzip -o -q "$skill_file" -d "$SKILLS_DIR" 2>/dev/null; then
        IMPORTED=$((IMPORTED + 1))
    else
        echo "  [WARN] Failed to extract: $skill_name"
    fi
done

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "Dry run: would import $IMPORTED, skip $SKIPPED existing."
    exit 0
fi

# Update manifest.json — scan skills dir and add any missing entries
export MANIFEST SKILLS_DIR
python3 << 'PYEOF'
import json, os
from datetime import datetime, timezone

manifest_path = os.environ.get('MANIFEST', '')
skills_dir = os.environ.get('SKILLS_DIR', '')
now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.') + f'{datetime.now().microsecond // 1000:03d}Z'

try:
    with open(manifest_path) as f:
        manifest = json.load(f)
except Exception:
    manifest = {"lastUpdated": 0, "skills": []}

existing_ids = {s['skillId'] for s in manifest.get('skills', [])}
added = 0

# Scan skills directory for new entries
for entry in sorted(os.listdir(skills_dir)):
    skill_md = os.path.join(skills_dir, entry, 'SKILL.md')
    if not os.path.isdir(os.path.join(skills_dir, entry)):
        continue
    if not os.path.exists(skill_md):
        continue
    if entry in existing_ids:
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

    manifest['skills'].append({
        'skillId': entry,
        'name': entry,
        'description': desc,
        'creatorType': 'custom',
        'updatedAt': now,
        'enabled': True
    })
    added += 1

manifest['lastUpdated'] = int(datetime.now().timestamp() * 1000)

with open(manifest_path, 'w') as f:
    json.dump(manifest, f, indent=2)

print(f'Manifest updated: +{added} new skills ({len(manifest["skills"])} total)')
PYEOF

FINAL=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(len(d.get('skills',[])))" 2>/dev/null || echo "?")
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Import Complete                                    ║"
echo "╚══════════════════════════════════════════════════════╝"
echo "  Imported: $IMPORTED new skills"
echo "  Updated:  $UPDATED overwritten (--force)"
echo "  Skipped:  $SKIPPED already installed"
echo "  Total:    $FINAL skills in manifest"
echo ""
echo "  IMPORTANT: Restart Claude Desktop for changes to take effect."