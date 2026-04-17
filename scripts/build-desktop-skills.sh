#!/bin/bash
# =============================================================================
# build-desktop-skills.sh — Package skills as .skill files for Claude Desktop
# =============================================================================
# Creates individual .skill files (zip format) that can be uploaded via
# Claude Desktop's "Upload a skill" button (Customize → Skills → + → Upload).
#
# Each .skill file contains a SKILL.md with sanitized YAML frontmatter
# (only allowed keys: name, description, license, allowed-tools, metadata,
# compatibility). ECC-specific keys like tools/model/origin are stripped.
#
# Tiers:
#   essential  — Personal learned skills only
#   standard   — + All universal agents + top commands
#   full       — + ALL universal commands (default)
#
# Usage:
#   scripts/build-desktop-skills.sh                   # Full tier, output to configs/desktop-skills/
#   scripts/build-desktop-skills.sh --tier essential
#   scripts/build-desktop-skills.sh --tier standard
#   scripts/build-desktop-skills.sh --clean           # Remove stale .skill files before building
#   scripts/build-desktop-skills.sh --clean --tier full  # Clean rebuild
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/configs/desktop-skills"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()     { echo -e "${BLUE}[SKILLS]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }

LEARNED_DIR="$HOME/.claude/skills/learned"
AGENTS_DIR="$HOME/.claude-everything-claude-code/agents"
COMMANDS_DIR="$HOME/.claude-everything-claude-code/commands"
SCIENCE_DIR="$HOME/.claude-scientific-skills/scientific-skills"

TIER="full"
CLEAN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tier) TIER="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        --clean) CLEAN=true; shift ;;
        *) shift ;;
    esac
done

# Clean: remove stale .skill files before rebuilding
if $CLEAN; then
    EXISTING=$(ls "$OUTPUT_DIR"/*.skill 2>/dev/null | wc -l | tr -d ' ')
    if [ "$EXISTING" -gt 0 ]; then
        log "Cleaning $EXISTING stale .skill files from $OUTPUT_DIR"
        rm -f "$OUTPUT_DIR"/*.skill
        success "Cleaned $EXISTING .skill files"
    else
        log "No stale .skill files to clean"
    fi
fi

log "Tier: $TIER"
log "Output: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

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
# Collect skill list
# =============================================================================
SKILL_LIST=()

if [ -d "$LEARNED_DIR" ]; then
    for f in "$LEARNED_DIR"/*.md; do
        [ -f "$f" ] || continue
        name=$(basename "$f" .md)
        SKILL_LIST+=("learned-$name|$f")
    done
fi

if [ "$TIER" = "standard" ] || [ "$TIER" = "full" ]; then
    for name in "${UNIVERSAL_AGENTS[@]}"; do
        f="$AGENTS_DIR/$name.md"
        [ -f "$f" ] && SKILL_LIST+=("agent-$name|$f")
    done
fi

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

# K-Dense Scientific Agent Skills (always included in all tiers)
if [ -d "$SCIENCE_DIR" ]; then
    SCIENCE_COUNT=0
    for dir in "$SCIENCE_DIR"/*/; do
        name=$(basename "$dir")
        if [ -f "$dir/SKILL.md" ]; then
            SKILL_LIST+=("science-$name|$dir/SKILL.md")
            SCIENCE_COUNT=$((SCIENCE_COUNT + 1))
        fi
    done
    log "Added $SCIENCE_COUNT K-Dense scientific skills"
else
    warn "K-Dense scientific skills not found — run: ./safe-install.sh --with-science"
fi

log "Collected ${#SKILL_LIST[@]} skills to package"

# =============================================================================
# Package all skills as .skill files (sanitized zip)
# =============================================================================
python3 << PYEOF
import json, os, re, zipfile, tempfile
from pathlib import Path

output_dir = """$OUTPUT_DIR"""
skill_entries = """$(IFS=$'\n'; echo "${SKILL_LIST[*]}")""".strip().split('\n')
skill_entries = [s for s in skill_entries if '|' in s]

# Claude Desktop allowed frontmatter keys
ALLOWED_KEYS = {'name', 'description', 'license', 'allowed-tools', 'metadata', 'compatibility'}

def sanitize_frontmatter(content, skill_id):
    """Strip disallowed YAML keys, truncate description, ensure valid frontmatter."""
    if not content.startswith('---'):
        # No frontmatter — create minimal one
        desc = ''
        for line in content.split('\n'):
            line = line.strip()
            if line and not line.startswith('#'):
                desc = line[:1024]
                break
        return f'---\nname: {skill_id}\ndescription: "{desc}"\n---\n\n{content}'

    parts = content.split('---', 2)
    if len(parts) < 3:
        return f'---\nname: {skill_id}\ndescription: "Skill {skill_id}"\n---\n\n{content}'

    fm_raw = parts[1]
    body = parts[2]

    # Parse and rebuild frontmatter keeping only allowed keys
    new_lines = []
    lines = fm_raw.split('\n')
    i = 0
    has_name = False
    has_desc = False
    desc_value = ''

    while i < len(lines):
        line = lines[i]
        m = re.match(r'^([a-z_-]+):\s*(.*)', line)
        if m:
            field = m.group(1)
            value = m.group(2).strip()

            if field not in ALLOWED_KEYS:
                # Skip this field and any indented continuation lines
                i += 1
                while i < len(lines) and lines[i] and (lines[i].startswith('  ') or lines[i].startswith('\t')):
                    i += 1
                continue

            if field == 'name':
                has_name = True
                # Ensure kebab-case, max 64 chars
                clean_name = re.sub(r'[^a-z0-9-]', '-', skill_id.lower())[:64]
                clean_name = re.sub(r'-+', '-', clean_name).strip('-')
                new_lines.append(f'name: {clean_name}')
                i += 1
                continue

            if field == 'description':
                has_desc = True
                if value in ('>', '>-', '|', '|-', ''):
                    # Block scalar — collect continuation lines
                    block = []
                    i += 1
                    while i < len(lines) and lines[i] and (lines[i].startswith('  ') or lines[i].startswith('\t')):
                        block.append(lines[i].strip())
                        i += 1
                    desc_value = ' '.join(block)
                else:
                    desc_value = value.strip('"').strip("'")
                    i += 1

                # Sanitize: no angle brackets, max 1024 chars
                desc_value = desc_value.replace('<', '').replace('>', '')[:1024]
                desc_value = desc_value.replace('"', "'")
                new_lines.append(f'description: "{desc_value}"')
                continue

            if field == 'metadata':
                # Keep metadata block as-is
                new_lines.append(line)
                i += 1
                while i < len(lines) and lines[i] and (lines[i].startswith('  ') or lines[i].startswith('\t')):
                    new_lines.append(lines[i])
                    i += 1
                continue

        new_lines.append(line)
        i += 1

    if not has_name:
        clean_name = re.sub(r'[^a-z0-9-]', '-', skill_id.lower())[:64]
        clean_name = re.sub(r'-+', '-', clean_name).strip('-')
        new_lines.insert(0, f'name: {clean_name}')

    if not has_desc:
        # Extract from body
        for line in body.split('\n'):
            line = line.strip()
            if line and not line.startswith('#') and not line.startswith('---'):
                desc_value = line[:1024].replace('<', '').replace('>', '').replace('"', "'")
                break
        new_lines.insert(1, f'description: "{desc_value}"')

    return '---\n' + '\n'.join(new_lines) + '\n---' + body

PREAMBLE = """
> **CRITICAL — follow these rules in every response:**
> - Be terse. No trailing summaries or status recaps.
> - Use codesight_get_summary BEFORE exploring a codebase with Grep/Glob/Read.
> - Use smart_read (token-optimizer) instead of Read for large files.
> - Use context7 query-docs BEFORE answering library/framework questions.
> - Use exa-web-search for anything that may have changed since training cutoff.

"""

packaged = 0
errors = []

for entry in skill_entries:
    skill_id, source_file = entry.split('|', 1)
    if not os.path.isfile(source_file):
        continue

    with open(source_file) as f:
        content = f.read()

    sanitized = sanitize_frontmatter(content, skill_id)

    # Inject preamble after frontmatter
    if sanitized.count('---') >= 2:
        parts = sanitized.split('---', 2)
        sanitized = '---' + parts[1] + '---\n' + PREAMBLE + parts[2]

    # Create .skill zip
    skill_file = os.path.join(output_dir, f'{skill_id}.skill')
    try:
        with zipfile.ZipFile(skill_file, 'w', zipfile.ZIP_DEFLATED) as zf:
            zf.writestr(f'{skill_id}/SKILL.md', sanitized)
        packaged += 1
    except Exception as e:
        errors.append(f'{skill_id}: {e}')

print(f'Packaged {packaged} .skill files to {output_dir}')
if errors:
    print(f'Errors ({len(errors)}):')
    for e in errors:
        print(f'  {e}')
PYEOF

SKILL_COUNT=$(ls "$OUTPUT_DIR"/*.skill 2>/dev/null | wc -l | tr -d ' ')
success "Packaged $SKILL_COUNT .skill files in $OUTPUT_DIR"
echo ""
log "To install in Claude Desktop:"
log "  1. Open Claude Desktop → Customize → Skills"
log "  2. Click '+' → 'Upload a skill'"
log "  3. Select files from: $OUTPUT_DIR"
log ""
log "Or select all at once: open \"$OUTPUT_DIR\""
