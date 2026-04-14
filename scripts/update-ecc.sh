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
#
# Usage:
#   scripts/update-ecc.sh
#   scripts/update-ecc.sh --check   # check if update available, don't apply
# =============================================================================
set -e

ECC_DIR="$HOME/.claude-everything-claude-code"
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

REMOTE=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)

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
    BEHIND=$(git log HEAD..origin/main --oneline 2>/dev/null | wc -l | tr -d ' ')
    log "ECC has $BEHIND new commit(s). Pulling..."
    git pull origin main --quiet 2>/dev/null || git pull origin master --quiet
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

_add_skill_file() {
    echo "" >> "$COMBINED_FILE"
    sed '1,/^---$/d' "$1" | sed '1,/^---$/d' >> "$COMBINED_FILE"
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

# Priority 4: Community curated
# Note: ~/.claude-curated-skills/community-curated/ is a web skills catalog (README only)
# Actual community skill files would go in a skills/ subdir if present
COMMUNITY_SKILLS_DIR="$CURATED_DIR/community-curated/skills"
if [ -d "$COMMUNITY_SKILLS_DIR" ]; then
    COUNT=0
    while IFS= read -r -d '' skill; do
        [ $COUNT -ge 50 ] && break
        _add_skill_file "$skill"; COUNT=$((COUNT + 1))
    done < <(find "$COMMUNITY_SKILLS_DIR" -name "*.md" -type f ! -name "README.md" -print0 2>/dev/null)
    [ $COUNT -gt 0 ] && success "Community curated skills: $COUNT"
else
    log "Community curated: catalog-only (no skill files installed)"
fi

CACHE_SIZE=$(wc -c < "$COMBINED_FILE" | tr -d ' ')
success "Cache rebuilt: $CACHE_SIZE bytes → $COMBINED_FILE"

# Rebuild lean cache (personal learned skills only)
# This is what _claude_with_skills injects into Anthropic Opus sessions.
# ~6K tokens vs 289K tokens — 98% reduction for frontier model sessions.
LEAN_FILE="$SKILLS_CACHE_DIR/lean-skills.txt"
cat "$HOME/.claude/skills/learned"/*.md > "$LEAN_FILE" 2>/dev/null
LEAN_SIZE=$(wc -c < "$LEAN_FILE" | tr -d ' ')
success "Lean cache: $LEAN_SIZE bytes (personal learned skills only — injected into 'claude' sessions)"

# =============================================================================
# Step 3: Re-sync to harness native skill directories
#         Uses YAML sanitization for skills with incompatible frontmatter
#         (block-scalar descriptions or extra fields like homepage/license/version)
# =============================================================================
log "Re-syncing skills to harnesses (with YAML sanitization)..."

python3 - << 'PYEOF'
import os, re, shutil

home = os.path.expanduser("~")
ecc_dir = os.path.join(home, ".claude-everything-claude-code", "skills")
openclaw_ws = os.path.join(home, ".openclaw", "workspace", "skills")
pi_skills   = os.path.join(home, ".pi", "agent", "skills")
codex_skills= os.path.join(home, ".codex", "skills")

ALLOWED_FIELDS = {"name", "description", "origin", "tools"}

def sanitize_skill_md(path):
    """Return sanitized SKILL.md content (strips extra fields, flattens block scalars)."""
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
        m = re.match(r"^([a-z_]+):\s*(.*)", line)
        if m:
            field, value = m.group(1), m.group(2).strip()
            if field not in ALLOWED_FIELDS:
                # Skip extra fields
                i += 1
                continue
            if field == "description" and value in (">", ">-", "|", "|-", ">|", ""):
                # Collect block scalar lines
                block_lines = []
                i += 1
                while i < len(lines) and (lines[i].startswith("  ") or lines[i].startswith("\t")):
                    block_lines.append(lines[i].strip())
                    i += 1
                desc = " ".join(block_lines).strip()
                # Truncate long descriptions and escape quotes
                desc = desc[:200].replace('"', "'")
                new_fm_lines.append(f'description: "{desc}"')
                continue
        new_fm_lines.append(line)
        i += 1

    return "---\n" + "\n".join(new_fm_lines) + "\n---" + body

def needs_sanitize(path):
    """Check if SKILL.md has block scalars or extra fields."""
    with open(path) as f:
        content = f.read()
    parts = content.split("---", 2)
    if len(parts) < 3:
        return False
    fm = parts[1]
    # Block scalar descriptions
    if re.search(r"^description:\s*[>|]", fm, re.MULTILINE):
        return True
    # Extra fields
    fields = re.findall(r"^([a-z_]+):", fm, re.MULTILINE)
    return bool(set(fields) - ALLOWED_FIELDS)

curated_dir = os.path.join(home, ".claude-curated-skills")
anthropic_skills_dir = os.path.join(curated_dir, "anthropic-official", "skills")
codex_curated_dir = os.path.join(curated_dir, "openai-codex", "skills")

# Collect all SKILL.md source dirs across ECC + Anthropic official + Codex curated
def collect_skill_dirs(base_dir):
    """Return {skill_name: skill_dir_path} for all dirs containing SKILL.md (any depth)."""
    result = {}
    if not os.path.isdir(base_dir):
        return result
    for dirpath, dirnames, filenames in os.walk(base_dir):
        if "SKILL.md" in filenames:
            skill_name = os.path.basename(dirpath)
            # Use full path as key when there's a collision (keep first found)
            if skill_name not in result:
                result[skill_name] = dirpath
    return result

ecc_skills = collect_skill_dirs(ecc_dir)
anthropic_skills = collect_skill_dirs(anthropic_skills_dir)
codex_curated_skills = collect_skill_dirs(codex_curated_dir)

# Merge all sources (ECC has priority over curated on name conflicts)
all_skills = {}
all_skills.update(codex_curated_skills)   # lowest priority
all_skills.update(anthropic_skills)       # medium priority
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
    """Sync a skill to harness: symlink if clean YAML, sanitized copy if not."""
    src = os.path.join(skill_dir, "SKILL.md")
    if not os.path.exists(src):
        return False
    dst_path = os.path.join(dest_dir, skill_name)
    if not os.path.exists(dst_path):
        if needs_sanitize(src):
            os.makedirs(dst_path, exist_ok=True)
            with open(os.path.join(dst_path, "SKILL.md"), "w") as f:
                f.write(sanitize_skill_md(src))
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
            os.symlink(skill_dir, target)
            stats["pi"]["added"] += 1
    stats["pi"]["total"] = len(os.listdir(pi_skills))

# --- Codex: symlinks where clean, sanitized copies where needed ---
if os.path.isdir(os.path.join(home, ".codex")):
    os.makedirs(codex_skills, exist_ok=True)
    for skill_name, skill_dir in all_skills.items():
        if sync_to_harness_symlink_or_sanitize(skill_name, skill_dir, codex_skills):
            stats["codex"]["added"] += 1
    stats["codex"]["total"] = len(os.listdir(codex_skills))

total = len(all_skills)
print(f"\033[0;32m[OK]\033[0m All skill sources: ECC({len(ecc_skills)}) + Anthropic({len(anthropic_skills)}) + Codex curated({len(codex_curated_skills)}) = {total} unique skill dirs")
print(f"\033[0;32m[OK]\033[0m OpenClaw: {stats['openclaw']['total']} skills ({stats['openclaw']['updated']} updated)")
print(f"\033[0;32m[OK]\033[0m Pi: {stats['pi']['total']} skills ({stats['pi']['added']} new)")
print(f"\033[0;32m[OK]\033[0m Codex: {stats['codex']['total']} skills ({stats['codex']['added']} new — includes native Codex skills)")
PYEOF

echo ""
success "ECC update complete! Restart Claude Code and OpenClaw to load new skills."
echo ""
