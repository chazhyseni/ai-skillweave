#!/usr/bin/env bash
# desktop-batch-import.sh — Batch import skills into Claude Desktop
# Bypasses the 15-at-a-time UI limit by writing directly to Desktop's storage
#
# How it works:
#   Syncs skills from ~/.claude/skills/ into the Desktop skills-plugin directory.
#   Creates symlinks for each skill and updates manifest.json so skills appear in
#   both the Customize → Capabilities panel AND via / slash commands.
#
#   If configs/desktop-skills/*.skill files exist, those are also imported.
#   Claude Desktop MUST be closed before running this script, as the app
#   regenerates manifest.json on startup and will discard changes if running.
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
CLAUDE_SKILLS="$HOME/.claude/skills"

# Cross-platform Desktop path
case "$(uname -s)" in
    Darwin*)  DESKTOP_BASE="$HOME/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin" ;;
    Linux*)   DESKTOP_BASE="$HOME/.config/Claude/local-agent-mode-sessions/skills-plugin" ;;
    *)        echo "ERROR: Unsupported OS: $(uname -s)"; exit 1 ;;
esac

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

# Find all session directories that have a manifest
if [ ! -d "$DESKTOP_BASE" ]; then
    echo "ERROR: Claude Desktop skills directory not found at:"
    echo "  $DESKTOP_BASE"
    echo ""
    echo "Open Claude Desktop once to create the directory, then re-run."
    exit 1
fi

# Collect all session directories (inject into ALL sessions)
SESSIONS=()
while IFS= read -r manifest; do
    SESSIONS+=("$(dirname "$manifest")")
done < <(find "$DESKTOP_BASE" -name "manifest.json" 2>/dev/null)

if [ ${#SESSIONS[@]} -eq 0 ]; then
    echo "ERROR: No Desktop session found."
    echo "Open Claude Desktop, add at least one skill, then re-run."
    exit 1
fi

echo "╔══════════════════════════════════════════════════════╗"
echo "║   Claude Desktop — Batch Skill Import                ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Found ${#SESSIONS[@]} session(s)"

TOTAL_IMPORTED=0
TOTAL_SKIPPED=0
TOTAL_UPDATED=0

for SESSION_DIR in "${SESSIONS[@]}"; do
    MANIFEST="$SESSION_DIR/manifest.json"
    SKILLS_DIR="$SESSION_DIR/skills"
    mkdir -p "$SKILLS_DIR"

    echo ""
    echo "Session: $(basename "$(dirname "$SESSION_DIR")")"
    echo "Skills dir: $SKILLS_DIR"

    EXISTING=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(len(d.get('skills',[])))" 2>/dev/null || echo 0)
    echo "Currently installed: $EXISTING skills"

    # Count source: .skill files + ~/.claude/skills/ directories
    SKILL_FILE_COUNT=0
    [ -d "$SKILLS_SRC" ] && SKILL_FILE_COUNT=$(find "$SKILLS_SRC" -maxdepth 1 -name '*.skill' 2>/dev/null | wc -l | tr -d ' ')
    CLAUDE_SKILLS_COUNT=0
    [ -d "$CLAUDE_SKILLS" ] && CLAUDE_SKILLS_COUNT=$(find "$CLAUDE_SKILLS" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    echo "Sources: $SKILL_FILE_COUNT .skill files, $CLAUDE_SKILLS_COUNT skills in ~/.claude/skills/"

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
    fi

    # Backup manifest (if not already backed up by --clean)
    if [ "$DRY_RUN" = false ] && [ "$CLEAN" = false ]; then
        BACKUP="${MANIFEST}.bak_$(date +%Y%m%d_%H%M%S)"
        cp "$MANIFEST" "$BACKUP"
        echo "Backup: $BACKUP"
    fi

    IMPORTED=0
    SKIPPED=0
    UPDATED=0

    # Source 1: .skill files from configs/desktop-skills/ (if they exist)
    if [ -d "$SKILLS_SRC" ] && ls "$SKILLS_SRC"/*.skill >/dev/null 2>&1; then
        for skill_file in "$SKILLS_SRC"/*.skill; do
            [ -f "$skill_file" ] || continue
            skill_name=$(basename "$skill_file" .skill)

            if [ -d "${SKILLS_DIR}/${skill_name}" ] && [ "$FORCE" = false ]; then
                SKIPPED=$((SKIPPED + 1))
                continue
            fi

            if [ "$DRY_RUN" = true ]; then
                echo "  [DRY] Would import .skill: $skill_name"
                IMPORTED=$((IMPORTED + 1))
                continue
            fi

            if [ -d "${SKILLS_DIR}/${skill_name}" ]; then
                rm -rf "${SKILLS_DIR}/${skill_name}"
                UPDATED=$((UPDATED + 1))
            fi

            if unzip -o -q "$skill_file" -d "$SKILLS_DIR" 2>/dev/null; then
                IMPORTED=$((IMPORTED + 1))
            else
                echo "  [WARN] Failed to extract .skill: $skill_name"
            fi
        done
    fi

    # Source 2: Symlink from ~/.claude/skills/ (primary source — always available)
    if [ -d "$CLAUDE_SKILLS" ]; then
        while IFS= read -r skill_path; do
            [ -d "$skill_path" ] || continue
            skill_name=$(basename "$skill_path")

            # Skip 'learned' dir (handled separately)
            if [ "$skill_name" = "learned" ]; then
                # Handle learned skills (individual .md files)
                local_learned_dir="$skill_path"
                if [ -d "$local_learned_dir" ]; then
                    while IFS= read -r md_file; do
                        [ -f "$md_file" ] || continue
                        learned_name="learned-$(basename "$md_file" .md)"
                        learned_dest="$SKILLS_DIR/$learned_name"

                        if [ -d "$learned_dest" ] || [ -L "$learned_dest" ]; then
                            if [ "$FORCE" = true ]; then
                                rm -rf "$learned_dest"
                            else
                                SKIPPED=$((SKIPPED + 1))
                                continue
                            fi
                        fi

                        if [ "$DRY_RUN" = true ]; then
                            echo "  [DRY] Would import learned skill: $learned_name"
                            continue
                        fi

                        mkdir -p "$learned_dest"
                        cp "$md_file" "$learned_dest/SKILL.md"
                        IMPORTED=$((IMPORTED + 1))
                    done < <(find "$local_learned_dir" -maxdepth 1 -name "*.md" 2>/dev/null)
                fi
                continue
            fi

            # Skip if no SKILL.md
            if [ ! -f "$skill_path/SKILL.md" ]; then
                continue
            fi

            dest="$SKILLS_DIR/$skill_name"

            if [ -L "$dest" ]; then
                # Update existing symlink
                if [ "$FORCE" = true ]; then
                    rm "$dest"
                else
                    SKIPPED=$((SKIPPED + 1))
                    continue
                fi
            elif [ -d "$dest" ]; then
                if [ "$FORCE" = true ]; then
                    rm -rf "$dest"
                else
                    SKIPPED=$((SKIPPED + 1))
                    continue
                fi
            fi

            if [ "$DRY_RUN" = true ]; then
                echo "  [DRY] Would symlink: $skill_name"
                IMPORTED=$((IMPORTED + 1))
                continue
            fi

            ln -s "$skill_path" "$dest"
            IMPORTED=$((IMPORTED + 1))
        done < <(find "$CLAUDE_SKILLS" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
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

# Scan skills directory for new entries (follows symlinks)
for entry in sorted(os.listdir(skills_dir)):
    entry_path = os.path.join(skills_dir, entry)
    # Resolve symlinks
    real_path = os.path.realpath(entry_path) if os.path.islink(entry_path) else entry_path
    skill_md = os.path.join(real_path, 'SKILL.md')
    if not os.path.isdir(real_path):
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
    echo "  Imported: $IMPORTED new, $UPDATED updated, $SKIPPED existing"
    echo "  Total:    $FINAL skills in manifest"
    TOTAL_IMPORTED=$((TOTAL_IMPORTED + IMPORTED))
    TOTAL_SKIPPED=$((TOTAL_SKIPPED + SKIPPED))
    TOTAL_UPDATED=$((TOTAL_UPDATED + UPDATED))
done

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Import Complete                                    ║"
echo "╚══════════════════════════════════════════════════════╝"
echo "  Sessions:  ${#SESSIONS[@]}"
echo "  Imported:  $TOTAL_IMPORTED new skills"
echo "  Updated:   $TOTAL_UPDATED overwritten (--force)"
echo "  Skipped:   $TOTAL_SKIPPED already installed"
echo ""
echo "  IMPORTANT: Restart Claude Desktop for changes to take effect."