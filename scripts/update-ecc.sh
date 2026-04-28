#!/bin/bash
# =============================================================================
# update-ecc.sh — Pull latest ECC skills and rebuild the cross-harness cache
# =============================================================================
# Run this when Everything Claude Code has been updated upstream to pull the
# latest skills without doing a full re-install.
#
# What it does:
#   1. git pull on ~/.claude-everything-claude-code
#   2. Rebuilds ~/.claude/skills-cache/combined-skills.txt
#   3. Re-syncs skills to all harness native directories (openclaw, pi, codex)
#   4. Runs the learning pipeline to extract/refresh learned skills
#
# Usage:
#   scripts/update-ecc.sh
#   scripts/update-ecc.sh --check   # check if update available, don't apply
# =============================================================================
set -e

ECC_DIR="$HOME/.claude-everything-claude-code"
SCIENCE_DIR="$HOME/.claude-scientific-skills"
SKILLS_CACHE_DIR="$HOME/.claude/skills-cache"
COMBINED_FILE="$SKILLS_CACHE_DIR/combined-skills.txt"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()     { echo -e "${BLUE}[ECC]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   ECC Skills Update                  ║"
echo "╚══════════════════════════════════════╝"
echo ""

ECC_REMOTE="https://github.com/affaan-m/everything-claude-code.git"

# =============================================================================
# Step 1: Ensure ECC is a git repo, then pull
# =============================================================================

if [ ! -d "$ECC_DIR" ]; then
    error "ECC not installed. Run: ./safe-install.sh"
fi

if [ ! -d "$ECC_DIR/.git" ]; then
    # ECC was installed by safe-install.sh (file copy, no .git) — add git tracking
    warn "ECC directory has no git history. Converting to a tracked git repo..."
    cd /tmp
    rm -rf ecc-update-tmp
    git clone --depth 1 "$ECC_REMOTE" ecc-update-tmp --quiet
    # Copy .git into ECC dir so future pulls work
    cp -r ecc-update-tmp/.git "$ECC_DIR/.git"
    cd "$ECC_DIR"
    # Reset index to HEAD without touching working tree files
    git reset HEAD --quiet 2>/dev/null || true
    rm -rf /tmp/ecc-update-tmp
    # Now restore working tree to match HEAD (safe-install files may be older than HEAD)
    git checkout -- skills/ 2>/dev/null || true
    success "Git tracking initialized + skills restored to current HEAD"
fi

log "Checking for ECC updates..."
cd "$ECC_DIR"

CURRENT=$(git rev-parse HEAD)
git fetch origin --quiet

ORIGIN_BRANCH=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
ORIGIN_BRANCH="${ORIGIN_BRANCH:-main}"
REMOTE=$(git rev-parse "origin/$ORIGIN_BRANCH" 2>/dev/null)

# Always ensure working tree skills match HEAD (guards against stale installs)
DIRTY=$(git status --short skills/ 2>/dev/null | grep -c '^.[^?]' || true)
if [ "$DIRTY" -gt 0 ] 2>/dev/null; then
    log "Working tree has $DIRTY stale skill files — restoring from HEAD..."
    git checkout -- skills/ 2>/dev/null || true
    success "Skills working tree restored to HEAD"
fi

if [ "$CURRENT" = "$REMOTE" ]; then
    success "ECC already up to date ($(git log -1 --format='%h %s' HEAD))"
    if [[ "$*" != *"--check"* ]]; then
        echo ""
        log "Run with --force to rebuild cache anyway:"
        echo "  scripts/update-ecc.sh --force"
        echo ""
    fi
    [[ "$*" == *"--force"* ]] || exit 0
else
    BEHIND=$(git log "HEAD..origin/$ORIGIN_BRANCH" --oneline 2>/dev/null | wc -l | tr -d ' ')
    log "ECC has $BEHIND new commit(s). Pulling..."
    git pull origin "$ORIGIN_BRANCH" --quiet
    NEW=$(git rev-parse HEAD)
    success "Updated: $(git log -1 --format='%h %s' HEAD)"
    echo ""
    log "New skills:"
    git diff "$CURRENT" "$NEW" --name-only -- skills/ | head -20
fi

[[ "$*" == *"--check"* ]] && exit 0

CURATED_DIR="$HOME/.claude-curated-skills"

# =============================================================================
# Step 2: Rebuild combined skills cache (matches safe-install.sh priority order)
# =============================================================================
log "Rebuilding skills cache..."
mkdir -p "$SKILLS_CACHE_DIR"
> "$COMBINED_FILE"

# Preamble: conciseness + MCP usage rules (must match safe-install.sh)
cat >> "$COMBINED_FILE" << 'PREAMBLE'
# CRITICAL INSTRUCTIONS — READ FIRST

## Conciseness
- Be terse. No trailing summaries, status tables, or "here's what I did" recaps.
- Show the change, not paragraphs explaining the change.

## Use MCP tools PROACTIVELY
- Use codesight_get_summary BEFORE exploring a codebase with Grep/Glob/Read.
- Use smart_read (token-optimizer) instead of Read for large files.
- Use context7 query-docs BEFORE answering library/framework questions from training data.
- Use exa-web-search for anything that may have changed since training cutoff.

PREAMBLE

_add_skill_file() {
    echo "" >> "$COMBINED_FILE"
    # Strip YAML frontmatter portably (BSD sed destroys content with double-sed pattern)
    awk 'BEGIN{f=0} /^---$/{f++; next} f>=2' "$1" >> "$COMBINED_FILE"
}

# Priority 0: Learned skills (always first — your personal skills)
LEARNED_DIR="$HOME/.claude/skills/learned"
if [ -d "$LEARNED_DIR" ]; then
    LEARNED_COUNT=0
    for skill in "$LEARNED_DIR"/*.md; do
        [ -f "$skill" ] || continue
        _add_skill_file "$skill"
        LEARNED_COUNT=$((LEARNED_COUNT + 1))
    done
    [ $LEARNED_COUNT -gt 0 ] && success "Learned skills: $LEARNED_COUNT"
fi

# Priority 1: Anthropic Official — skills are in the skills/ subdirectory
# Excludes README.md, THIRD_PARTY_NOTICES.md, and template/spec docs
ANTHROPIC_SKILLS_DIR="$CURATED_DIR/anthropic-official/skills"
if [ -d "$ANTHROPIC_SKILLS_DIR" ]; then
    COUNT=0
    while IFS= read -r -d '' skill; do
        _add_skill_file "$skill"; COUNT=$((COUNT + 1))
    done < <(find "$ANTHROPIC_SKILLS_DIR" -name "*.md" -type f ! -name "README.md" -print0 2>/dev/null)
    [ $COUNT -gt 0 ] && success "Anthropic official skills: $COUNT"
fi

# Priority 2: OpenAI Codex — skills are in the skills/ subdirectory (470 total, all loaded)
# Note: previously capped at 100 to save context tokens. All 470 are now loaded.
# If context window becomes an issue, set CAP=100 below.
CODEX_SKILLS_DIR="$CURATED_DIR/openai-codex/skills"
CAP=0  # 0 = no cap
if [ -d "$CODEX_SKILLS_DIR" ]; then
    COUNT=0
    while IFS= read -r -d '' skill; do
        [ $CAP -gt 0 ] && [ $COUNT -ge $CAP ] && break
        _add_skill_file "$skill"; COUNT=$((COUNT + 1))
    done < <(find "$CODEX_SKILLS_DIR" -name "*.md" -type f ! -name "README.md" ! -name "contributing.md" -print0 2>/dev/null)
    [ $COUNT -gt 0 ] && success "OpenAI Codex skills: $COUNT"
fi

# Priority 3: ECC skills (the core library — SKILL.md files)
if [ -d "$ECC_DIR/skills" ]; then
    SKILL_COUNT=0
    while IFS= read -r -d '' skill; do
        _add_skill_file "$skill"; SKILL_COUNT=$((SKILL_COUNT + 1))
    done < <(find "$ECC_DIR/skills" -name "*.md" -type f ! -path "*/learned/*" -print0 2>/dev/null)
    success "ECC skills: $SKILL_COUNT"
fi

# Priority 4: K-Dense Scientific Agent Skills (SKILL.md in subdirectories)
SCIENCE_SKILLS_DIR="$SCIENCE_DIR/scientific-skills"
if [ -d "$SCIENCE_SKILLS_DIR" ]; then
    SKILL_COUNT=0
    while IFS= read -r -d '' skill; do
        _add_skill_file "$skill"; SKILL_COUNT=$((SKILL_COUNT + 1))
    done < <(find "$SCIENCE_SKILLS_DIR" -name "SKILL.md" -type f -print0 2>/dev/null)
    [ $SKILL_COUNT -gt 0 ] && success "K-Dense scientific skills: $SKILL_COUNT"
fi

# Priority 5: ClawBio Bioinformatics Skills (SKILL.md in subdirectories)
CLAWBIO_DIR="$HOME/.claude-clawbio-skills"
if [ -d "$CLAWBIO_DIR/skills" ]; then
    SKILL_COUNT=0
    while IFS= read -r -d '' skill; do
        _add_skill_file "$skill"; SKILL_COUNT=$((SKILL_COUNT + 1))
    done < <(find "$CLAWBIO_DIR/skills" -name "SKILL.md" -type f -print0 2>/dev/null)
    [ $SKILL_COUNT -gt 0 ] && success "ClawBio bioinformatics skills: $SKILL_COUNT"
fi

CACHE_SIZE=$(wc -c < "$COMBINED_FILE" | tr -d ' ')
success "Cache rebuilt: $CACHE_SIZE bytes → $COMBINED_FILE"

# Rebuild lean cache: name + operating principle only per skill (~20 tokens/skill)
# This is what _claude_with_skills injects. Full content would be ~250 tokens/skill.
LEAN_FILE="$SKILLS_CACHE_DIR/lean-skills.txt"
if ls "$HOME/.claude/skills/learned"/*.md >/dev/null 2>&1; then
    python3 - "$HOME/.claude/skills/learned" "$LEAN_FILE" << 'PYEOF'
import sys, re, pathlib
skills_dir = pathlib.Path(sys.argv[1])
out_file = pathlib.Path(sys.argv[2])
lines = ["# Learned Skills (name + operating principle only)\n"]
for f in sorted(skills_dir.glob("*.md")):
    if f.name.startswith(".") or f.name in ("SKILL.md",):
        continue
    text = f.read_text(errors="replace")
    name = re.search(r'^name:\s*(.+)$', text, re.M)
    desc = re.search(r'^description:\s*(.+)$', text, re.M)
    principle = re.search(r'^\d+\.\s+(.+)$', text, re.M)
    if name and desc:
        lines.append(f"- **{name.group(1).strip()}**: {desc.group(1).strip()}")
        if principle:
            lines.append(f"  → {principle.group(1).strip()}")
        lines.append("")
out_file.write_text("\n".join(lines))
PYEOF
    LEAN_SIZE=$(wc -c < "$LEAN_FILE" | tr -d ' ')
    success "Lean cache: $LEAN_SIZE bytes (~$((LEAN_SIZE/4)) tokens, name+principle only per skill)"
else
    > "$LEAN_FILE"
    warn "No learned skills found — lean cache is empty"
fi

# =============================================================================
# Step 3: Re-sync to harness native skill directories
#         Uses YAML sanitization for skills with incompatible frontmatter
#         (block-scalar descriptions or extra fields like homepage/license/version)
# =============================================================================
log "Re-syncing skills to harnesses (with YAML sanitization)..."

python3 - << 'PYEOF'
import os, re, shutil, glob

home = os.path.expanduser("~")
ecc_dir = os.path.join(home, ".claude-everything-claude-code", "skills")
openclaw_ws = os.path.join(home, ".openclaw", "workspace", "skills")
pi_skills   = os.path.join(home, ".pi", "agent", "skills")
codex_skills= os.path.join(home, ".codex", "skills")

ALLOWED_FIELDS = {"name", "description", "origin", "tools", "license", "allowed-tools", "metadata", "compatibility"}

def sanitize_skill_md(path):
    """Return sanitized SKILL.md content (strips extra fields, flattens block scalars).

    Also strips indented continuation lines after any field (these are
    nested YAML mappings like 'author:' or 'clawdbot:' indented under
    'origin:' in some ECC skills — invalid YAML that Codex rejects).
    """
    with open(path) as f:
        content = f.read()

    parts = content.split("---", 2)
    if len(parts) < 3:
        return content  # no frontmatter, return as-is

    fm_raw = parts[1]
    body = parts[2]

    # Parse frontmatter lines
    new_fm_lines = []
    lines = fm_raw.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        # Skip indented lines — these are nested YAML under the previous field
        # (e.g. "  author: evos" under "origin: ECC") which is invalid YAML
        if line and (line[0] == ' ' or line[0] == '\t'):
            i += 1
            continue
        m = re.match(r"^([a-z_]+):\s*(.*)", line)
        if m:
            field, value = m.group(1), m.group(2).strip()
            if field not in ALLOWED_FIELDS:
                # Skip extra fields and their indented continuations
                i += 1
                while i < len(lines) and lines[i] and (lines[i][0] == ' ' or lines[i][0] == '\t'):
                    i += 1
                continue
            if field == "description" and value in (">", ">-", "|", "|-", ">|", ""):
                # Collect block scalar lines
                block_lines = []
                i += 1
                while i < len(lines) and lines[i] and (lines[i][0] == ' ' or lines[i][0] == '\t'):
                    block_lines.append(lines[i].strip())
                    i += 1
                desc = " ".join(block_lines).strip()
                # Truncate long descriptions and escape quotes
                desc = desc[:200].replace('"', "'")
                new_fm_lines.append(f'description: "{desc}"')
                continue
            if field == "description" and "\n" in value:
                # Multi-line inline description with continuation on next line
                desc = value.split("\n")[0].strip()[:200].replace('"', "'")
                new_fm_lines.append(f'description: "{desc}"')
                i += 1
                continue
        new_fm_lines.append(line)
        i += 1

    return "---\n" + "\n".join(new_fm_lines) + "\n---" + body

def needs_sanitize(path):
    """Check if SKILL.md has block scalars, extra fields, or indented nested mappings."""
    with open(path) as f:
        content = f.read()
    parts = content.split("---", 2)
    if len(parts) < 3:
        return False
    fm = parts[1]
    # Block scalar descriptions
    if re.search(r"^description:\s*[>|]", fm, re.MULTILINE):
        return True
    # Extra top-level fields (beyond what's allowed in target harness)
    fields = re.findall(r"^([a-z_][a-z0-9_-]*):", fm, re.MULTILINE)
    if set(fields) - ALLOWED_FIELDS:
        return True
    # Indented lines that look like nested YAML mappings (e.g. "  author: evos")
    if re.search(r"^[ \t]+[a-z_]+:", fm, re.MULTILINE):
        return True
    # Description with continuation on next line (e.g. "description: foo\n  tags: bar")
    if re.search(r"^description:.*\n\s+\S+:", fm, re.MULTILINE):
        return True
    return False

curated_dir = os.path.join(home, ".claude-curated-skills")
anthropic_skills_dir = os.path.join(curated_dir, "anthropic-official", "skills")
codex_curated_dir = os.path.join(curated_dir, "openai-codex", "skills")
science_dir = os.path.join(home, ".claude-scientific-skills", "scientific-skills")
clawbio_dir = os.path.join(home, ".claude-clawbio-skills", "skills")

# Collect all SKILL.md source dirs across ECC + Anthropic official + Codex curated + K-Dense
def collect_skill_dirs(base_dir):
    """Return {skill_name: skill_dir_path} for all dirs containing SKILL.md (any depth)."""
    result = {}
    if not os.path.isdir(base_dir):
        return result
    for dirpath, dirnames, filenames in os.walk(base_dir):
        # Skip hidden directories (like .system, .git)
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        if "SKILL.md" in filenames:
            skill_name = os.path.basename(dirpath)
            # Use full path as key when there's a collision (keep first found)
            if skill_name not in result:
                result[skill_name] = dirpath
    return result

ecc_skills = collect_skill_dirs(ecc_dir)
anthropic_skills = collect_skill_dirs(anthropic_skills_dir)
codex_curated_skills = collect_skill_dirs(codex_curated_dir)
science_skills = collect_skill_dirs(science_dir)
clawbio_skills = collect_skill_dirs(clawbio_dir)

# Merge all sources (ECC has priority over curated on name conflicts)
all_skills = {}
all_skills.update(codex_curated_skills)   # lowest priority
all_skills.update(anthropic_skills)       # medium-low priority
all_skills.update(clawbio_skills)         # medium priority
all_skills.update(science_skills)         # medium-high priority
all_skills.update(ecc_skills)             # highest priority (ECC wins)

stats = {"openclaw": {"updated": 0, "total": 0}, "pi": {"added": 0, "total": 0}, "codex": {"added": 0, "total": 0}}

def sync_to_harness_real(skill_name, skill_dir, dest_dir):
    """Sync a skill dir to a harness dir (real file copies, sanitized)."""
    src = os.path.join(skill_dir, "SKILL.md")
    if not os.path.exists(src):
        return False
    dst_dir = os.path.join(dest_dir, skill_name)
    dst = os.path.join(dst_dir, "SKILL.md")
    src_mtime = os.path.getmtime(src)
    dst_mtime = os.path.getmtime(dst) if os.path.exists(dst) else 0
    if src_mtime > dst_mtime:
        os.makedirs(dst_dir, exist_ok=True)
        if needs_sanitize(src):
            with open(dst, "w") as f:
                f.write(sanitize_skill_md(src))
        else:
            shutil.copy2(src, dst)
        return True
    return False

def sync_to_harness_symlink_or_sanitize(skill_name, skill_dir, dest_dir):
    """Sync a skill to harness: symlink if clean YAML, sanitized copy if not.
    
    For Codex: truncates skill name to 64 chars (Codex limit) and updates
    the name field inside SKILL.md to match.
    """
    src = os.path.join(skill_dir, "SKILL.md")
    if not os.path.exists(src):
        return False
    
    # Codex has 64-char limit on skill names
    codex_name = skill_name[:64].rstrip("-")
    dst_path = os.path.join(dest_dir, codex_name)
    
    if not os.path.exists(dst_path):
        if needs_sanitize(src):
            os.makedirs(dst_path, exist_ok=True)
            content = sanitize_skill_md(src)
            # Update name field to match truncated directory name
            lines = content.splitlines()
            for i, line in enumerate(lines):
                if line.startswith("name: "):
                    lines[i] = f"name: {codex_name}"
                    break
            with open(os.path.join(dst_path, "SKILL.md"), "w") as f:
                f.write("\n".join(lines) + "\n")
        else:
            os.symlink(skill_dir, dst_path)
        return True
    return False

# --- OpenClaw: real file copies (sanitized) for all skill sources ---
if os.path.isdir(os.path.join(home, ".openclaw", "workspace")):
    os.makedirs(openclaw_ws, exist_ok=True)
    for skill_name, skill_dir in all_skills.items():
        if sync_to_harness_real(skill_name, skill_dir, openclaw_ws):
            stats["openclaw"]["updated"] += 1
    stats["openclaw"]["total"] = len([d for d in os.listdir(openclaw_ws) if os.path.isdir(os.path.join(openclaw_ws, d))])

# --- Pi: symlinks for all skill sources ---
if os.path.isdir(os.path.join(home, ".pi", "agent")):
    os.makedirs(pi_skills, exist_ok=True)
    for skill_name, skill_dir in all_skills.items():
        target = os.path.join(pi_skills, skill_name)
        if not os.path.exists(target):
            try:
                os.symlink(skill_dir, target)
                stats["pi"]["added"] += 1
            except (OSError, FileExistsError):
                pass  # Skip if symlink fails (e.g., target already exists)
    stats["pi"]["total"] = len(os.listdir(pi_skills))

# --- Codex: symlinks where clean, sanitized copies where needed ---
if os.path.isdir(os.path.join(home, ".codex")):
    os.makedirs(codex_skills, exist_ok=True)
    for skill_name, skill_dir in all_skills.items():
        if sync_to_harness_symlink_or_sanitize(skill_name, skill_dir, codex_skills):
            stats["codex"]["added"] += 1
    stats["codex"]["total"] = len(os.listdir(codex_skills))

# --- Claude Code: directory-based skills (<name>/SKILL.md) ---
# Claude Code's /skills command ONLY discovers <name>/SKILL.md directory format,
# NOT flat .md files. Migrate stale flat files and sync all skills.
claude_skills = os.path.join(home, ".claude", "skills")
if os.path.isdir(os.path.join(home, ".claude")):
    os.makedirs(claude_skills, exist_ok=True)
    # Migrate stale flat .md files to directory format
    migrated = 0
    for flat_file in glob.glob(os.path.join(claude_skills, "*.md")):
        skill_name = os.path.splitext(os.path.basename(flat_file))[0]
        dir_path = os.path.join(claude_skills, skill_name)
        if os.path.isdir(dir_path):
            # Directory already exists; remove stale flat file
            os.remove(flat_file)
            migrated += 1
            continue
        # Move flat file into directory format
        os.makedirs(dir_path, exist_ok=True)
        shutil.move(flat_file, os.path.join(dir_path, "SKILL.md"))
        migrated += 1
    # Sync all skill sources
    claude_updated = 0
    for skill_name, skill_dir in all_skills.items():
        src = os.path.join(skill_dir, "SKILL.md")
        if not os.path.exists(src):
            continue
        dst_dir = os.path.join(claude_skills, skill_name)
        dst = os.path.join(dst_dir, "SKILL.md")
        src_mtime = os.path.getmtime(src)
        dst_mtime = os.path.getmtime(dst) if os.path.exists(dst) else 0
        if src_mtime > dst_mtime:
            os.makedirs(dst_dir, exist_ok=True)
            shutil.copy2(src, dst)
            claude_updated += 1
    # Also sync learned skills (flat .md in learned/ subdir — leave as-is)
    claude_total = len([d for d in os.listdir(claude_skills)
                        if os.path.isdir(os.path.join(claude_skills, d)) and d != "learned"])
    if migrated > 0:
        print(f"\033[0;32m[OK]\033[0m Claude Code: migrated {migrated} flat .md skills to directory format")
    print(f"\033[0;32m[OK]\033[0m Claude Code: {claude_total} skills ({claude_updated} updated)")

total = len(all_skills)
print(f"\033[0;32m[OK]\033[0m All skill sources: ECC({len(ecc_skills)}) + Anthropic({len(anthropic_skills)}) + Codex curated({len(codex_curated_skills)}) + K-Dense({len(science_skills)}) + ClawBio({len(clawbio_skills)}) = {total} unique skill dirs")
print(f"\033[0;32m[OK]\033[0m OpenClaw: {stats['openclaw']['total']} skills ({stats['openclaw']['updated']} updated)")
print(f"\033[0;32m[OK]\033[0m Pi: {stats['pi']['total']} skills ({stats['pi']['added']} new)")
print(f"\033[0;32m[OK]\033[0m Codex: {stats['codex']['total']} skills ({stats['codex']['added']} new — includes native Codex skills)")
PYEOF

echo ""
success "ECC update complete! Restart Claude Code and OpenClaw to load new skills."

# =============================================================================
# Step 4: Run learning pipeline (extract + sync learned skills)
# =============================================================================

# Prevent duplicate pipeline runs within 5 minutes (e.g. install.sh calling
# update-ecc.sh twice, or overlapping cron jobs).
LOCK_FILE="/tmp/ai-skillweave-learn.lock"
LOCK_MAX_AGE=60  # 1 minute — prevents duplicate runs within a single install.sh execution

should_run_learning=true
if [ -f "$LOCK_FILE" ]; then
    lock_age=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0)))
    if [ "$lock_age" -lt "$LOCK_MAX_AGE" ]; then
        log "Learning pipeline already ran ${lock_age}s ago (within ${LOCK_MAX_AGE}s window) — skipping"
        should_run_learning=false
    fi
fi

if $should_run_learning; then
    touch "$LOCK_FILE"
    SYNC_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sync-learned-skills.sh"
    if [ -f "$SYNC_SCRIPT" ]; then
        log "Running learning pipeline..."
        bash "$SYNC_SCRIPT" && success "Learned skills synced" || warn "Learning pipeline had issues (non-fatal)"
    else
        warn "sync-learned-skills.sh not found — skipping learned skill extraction"
    fi
fi

echo ""
