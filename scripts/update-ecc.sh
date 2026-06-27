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
#      - Codex: pre-flight warns on any skill name > 64 chars; directory is
#        truncated as a defensive fallback but SKILL.md name: field is NEVER
#        rewritten (preserves cross-harness equivalence).
#   4. Runs the learning pipeline to extract/refresh learned skills
#
# Usage:
#   scripts/update-ecc.sh
#   scripts/update-ecc.sh --check   # check if update available, don't apply
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

# --no-prune: skip the orphan-removal pass (additive-only sync). The manifest is
# still written, so a later default run prunes exactly. Prune is ON by default.
ECC_NO_PRUNE=0
[[ "$*" == *"--no-prune"* ]] && ECC_NO_PRUNE=1
export ECC_NO_PRUNE

# =============================================================================
# Step 1b: Ensure every other skill source is present and current. ECC is handled
# above; K-Dense, ClawBio, and the curated set are handled by safe-install.sh.
# The repos below are CLONED if missing and fast-forwarded if already present —
# this is what lets a fresh `install.sh` reproduce the full skill set on any
# machine, not just the four sources safe-install.sh clones. bioSkills lives
# in-place under ~/.claude/skills and is installed by scripts/install-bioskills.sh.
# =============================================================================
log "Ensuring skill source repos are present and current..."
# Each entry is "<dir>|<git url>": clone if missing, fast-forward if present.
SOURCE_REPOS=(
    "$HOME/.claude-medical-skills|https://github.com/FreedomIntelligence/OpenClaw-Medical-Skills.git"
    "$HOME/.claude-operon-skills|https://github.com/swaruplab/operon.git"
    "$HOME/.claude-tooluniverse|https://github.com/mims-harvard/ToolUniverse.git"
    "$HOME/.claude-sciagent-skills|https://github.com/jaechang-hits/SciAgent-Skills.git"
    "$HOME/.claude-deepmind-skills|https://github.com/google-deepmind/science-skills.git"
    "$HOME/.claude-bionemo-skills|https://github.com/NVIDIA-BioNeMo/bionemo-agent-toolkit.git"
    "$HOME/.claude-nature-paper-skills|https://github.com/Boom5426/Nature-Paper-Skills.git"
    "$HOME/.claude-life-sciences|https://github.com/anthropics/life-sciences.git"
    "$HOME/.claude-bipartite|https://github.com/matsen/bipartite.git"
)
SRC_CLONED=0
SRC_UPDATED=0
for entry in "${SOURCE_REPOS[@]}"; do
    repo="${entry%%|*}"
    url="${entry##*|}"
    if [ ! -d "$repo" ]; then
        if git clone --depth 1 --quiet "$url" "$repo" 2>/dev/null; then
            success "Cloned $(basename "$repo")"
            SRC_CLONED=$((SRC_CLONED + 1))
        else
            warn "Could not clone $(basename "$repo") from $url — skipped"
        fi
        continue
    fi
    [ -d "$repo/.git" ] || continue   # file-copy source (no .git) — leave as-is
    before=$(git -C "$repo" rev-parse HEAD 2>/dev/null)
    if git -C "$repo" pull --ff-only --quiet 2>/dev/null; then
        after=$(git -C "$repo" rev-parse HEAD 2>/dev/null)
        if [ "$before" != "$after" ]; then
            success "Updated $(basename "$repo"): $(git -C "$repo" log -1 --format='%h %s' 2>/dev/null)"
            SRC_UPDATED=$((SRC_UPDATED + 1))
        fi
    else
        warn "$(basename "$repo"): could not fast-forward (local changes or diverged) — left as-is"
    fi
done
[ "$SRC_CLONED" -gt 0 ] && success "Cloned $SRC_CLONED new skill source repo(s)"
[ "$SRC_CLONED" -eq 0 ] && [ "$SRC_UPDATED" -eq 0 ] && success "All skill source repos already present and up to date"

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
# Cap at top 50 learned skills (by confidence) to keep the injection budget
# reasonable. Without a cap, 599 learned skills = 149K bytes = ~37K tokens,
# which is too much to inject into every session. The cap keeps it under
# ~5K tokens while still surfacing the highest-value corrections.
LEAN_FILE="$SKILLS_CACHE_DIR/lean-skills.txt"
LEAN_CAP=50
if ls "$HOME/.claude/skills/learned"/*.md >/dev/null 2>&1; then
    python3 - "$HOME/.claude/skills/learned" "$LEAN_FILE" "$LEAN_CAP" << 'PYEOF'
import sys, re, pathlib
skills_dir = pathlib.Path(sys.argv[1])
out_file = pathlib.Path(sys.argv[2])
cap = int(sys.argv[3])

# Collect all skills with their confidence for ranking
skills = []
for f in sorted(skills_dir.glob("*.md")):
    if f.name.startswith(".") or f.name in ("SKILL.md",):
        continue
    text = f.read_text(errors="replace")
    name = re.search(r'^name:\s*(.+)$', text, re.M)
    desc = re.search(r'^description:\s*(.+)$', text, re.M)
    principle = re.search(r'^\d+\.\s+(.+)$', text, re.M)
    confidence = re.search(r'\*\*Confidence:\*\*\s*([\d.]+)', text, re.M)
    freq = re.search(r'\*\*Unique sessions:\*\*\s*(\d+)', text, re.M)
    if name and desc:
        conf_val = float(confidence.group(1)) if confidence else 0.0
        freq_val = int(freq.group(1)) if freq else 0
        skills.append((conf_val, freq_val, name.group(1).strip(), desc.group(1).strip(),
                       principle.group(1).strip() if principle else ""))

# Sort by confidence desc, then frequency desc
skills.sort(key=lambda s: (s[0], s[1]), reverse=True)

# Cap to top N
capped = skills[:cap]

lines = ["# Learned Skills (name + operating principle only, top %d by confidence)\n" % len(capped)]
for _, _, name, desc, principle in capped:
    lines.append(f"- **{name}**: {desc}")
    if principle:
        lines.append(f"  → {principle}")
    lines.append("")

if len(skills) > cap:
    lines.append(f"# ({len(skills)} total learned skills; showing top {cap} by confidence)")

out_file.write_text("\n".join(lines))
PYEOF
    LEAN_SIZE=$(wc -c < "$LEAN_FILE" | tr -d ' ')
    success "Lean cache: $LEAN_SIZE bytes (~$((LEAN_SIZE/4)) tokens, top $LEAN_CAP of $(ls "$HOME/.claude/skills/learned"/*.md 2>/dev/null | grep -cv '/.usage') learned skills)"
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

export REPO_DIR
python3 - << 'PYEOF'
import os, sys, shutil, glob, json

# Import the shared sanitizer so this script and setup-copilot-skills.sh
# can't drift in their YAML-handling rules. Single source of truth lives
# in scripts/skill_sanitize.py next to this file.
sys.path.insert(0, os.environ.get("REPO_DIR", "") + "/scripts")
from skill_sanitize import sanitize_skill_md, needs_sanitize, ALLOWED_FIELDS

home = os.path.expanduser("~")
ecc_dir = os.path.join(home, ".claude-everything-claude-code", "skills")
openclaw_ws = os.path.join(home, ".openclaw", "workspace", "skills")
pi_skills   = os.path.join(home, ".pi", "agent", "skills")
codex_skills= os.path.join(home, ".codex", "skills")

curated_dir = os.path.join(home, ".claude-curated-skills")
anthropic_skills_dir = os.path.join(curated_dir, "anthropic-official", "skills")
codex_curated_dir = os.path.join(curated_dir, "openai-codex", "skills")
science_dir = os.path.join(home, ".claude-scientific-skills", "scientific-skills")
clawbio_dir = os.path.join(home, ".claude-clawbio-skills", "skills")
# GPTomics/bioSkills are installed directly into ~/.claude/skills/<category>/<skill>/SKILL.md
# They live at depth-3 (category/skill/SKILL.md), unlike depth-2 skills (skill/SKILL.md)
bioskills_dir = os.path.join(home, ".claude", "skills")
# Bipartite (matsen/bipartite) — research workflow CLI + Claude Code skills
# 37 skills for manuscript sessions, literature management, EPIC orchestration,
# PR review, and workflow coordination. Installed via `make install` which
# symlinks skills/ and agents/ into ~/.claude/. The skills live at depth-2
# (skill_name/SKILL.md) and are Agent Skills spec compliant.
bipartite_dir = os.path.join(home, ".claude-bipartite", "skills")
# Google DeepMind science-skills — 37 skills wrapping AlphaGenome, AlphaFold DB,
# UniProt, Ensembl, gnomAD, GTEx, ClinVar, dbSNP, ChEMBL, PubChem, PDB, etc.
deepmind_dir = os.path.join(home, ".claude-deepmind-skills", "skills")
# SciAgent-Skills (jaechang-hits) — 197 skills for genomics, proteomics, structural
# biology, drug discovery, systems biology, biostatistics, scientific writing.
# Organized as categories/skill/SKILL.md (depth-2, like bioSkills).
sciagent_dir = os.path.join(home, ".claude-sciagent-skills", "skills")
# ToolUniverse (mims-harvard) — 150 skills (in skills/) for drug discovery,
# precision oncology, and rare-disease diagnosis, wrapping 1,000+ ML models.
tooluniverse_dir = os.path.join(home, ".claude-tooluniverse", "skills")
# OpenClaw-Medical-Skills (FreedomIntelligence) — 896 skills (in skills/)
# spanning clinical workflows, genomics, drug discovery, and regulatory.
medical_dir = os.path.join(home, ".claude-medical-skills", "skills")
# operon (swaruplab/UC Irvine) — 556 bioinformatics protocols (in protocols/):
# RNA-seq, scRNA-seq, ATAC-seq, ChIP-seq, WGS/WES, spatial, proteomics, GWAS.
operon_dir = os.path.join(home, ".claude-operon-skills", "protocols")
# Anthropic life-sciences — 6 skills (single-cell-rna-qc, nextflow-development,
# clinical-trial-protocol-skill, scientific-problem-selection).
lifesci_dir = os.path.join(home, ".claude-life-sciences")
# NVIDIA BioNeMo agent toolkit (NVIDIA-BioNeMo/bionemo-agent-toolkit) — 35
# GPU-accelerated life-science skills wrapping NVIDIA NIM microservices and
# open models: Boltz-2, OpenFold2/3, RFdiffusion, ProteinMPNN, DiffDock,
# MolMIM, GenMol, Evo2, MSA-Search, Parabricks, plus protein-binder design
# and drug-discovery workflows. Skills span the whole repo (nim-skills/,
# open-models-skills/, library-skills/, workflows/, plugins/).
bionemo_dir = os.path.join(home, ".claude-bionemo-skills")
# Nature-Paper-Skills (Boom5426/Nature-Paper-Skills) — 18 Agent Skills for
# Nature-style manuscript work: drafting, revision, figure planning, citation
# verification, data-availability, submission audit, rebuttal, and the
# nature-portfolio playbook. Skills live under skills/{core,venue,research,review,optional}/.
naturepaper_dir = os.path.join(home, ".claude-nature-paper-skills", "skills")

# Collect all SKILL.md source dirs across ECC + Anthropic official + Codex curated + K-Dense
def collect_skill_dirs(base_dir, max_depth=None):
    """Return {skill_name: skill_dir_path} for all dirs containing SKILL.md (any depth)."""
    result = {}
    if not os.path.isdir(base_dir):
        return result
    base_depth = base_dir.rstrip(os.sep).count(os.sep)
    for dirpath, dirnames, filenames in os.walk(base_dir):
        # Skip hidden directories (like .system, .git, .archive)
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        if max_depth is not None:
            current_depth = dirpath.count(os.sep) - base_depth
            if current_depth >= max_depth:
                dirnames[:] = []
        if "SKILL.md" in filenames:
            skill_name = os.path.basename(dirpath)
            # Use full path as key when there's a collision (keep first found)
            if skill_name not in result:
                result[skill_name] = dirpath
    return result

def collect_bioskills(base_dir):
    """Collect GPTomics/bioSkills from ~/.claude/skills/<category>/<skill>/SKILL.md.

    bioSkills sit at depth-3 (category subdir → skill subdir → SKILL.md).
    Excludes: depth-2 skills (ECC/native), learned/ dir, hidden dirs.
    """
    result = {}
    if not os.path.isdir(base_dir):
        return result
    for category in os.listdir(base_dir):
        if category.startswith(".") or category == "learned":
            continue
        cat_path = os.path.join(base_dir, category)
        if not os.path.isdir(cat_path):
            continue
        for skill in os.listdir(cat_path):
            if skill.startswith("."):
                continue
            skill_path = os.path.join(cat_path, skill)
            skill_md = os.path.join(skill_path, "SKILL.md")
            if os.path.isdir(skill_path) and os.path.exists(skill_md):
                if skill not in result:
                    result[skill] = skill_path
    return result

ecc_skills = collect_skill_dirs(ecc_dir)
anthropic_skills = collect_skill_dirs(anthropic_skills_dir)
codex_curated_skills = collect_skill_dirs(codex_curated_dir)
science_skills = collect_skill_dirs(science_dir)
clawbio_skills = collect_skill_dirs(clawbio_dir)
bioskills = collect_bioskills(bioskills_dir)
bipartite_skills = collect_skill_dirs(bipartite_dir)
deepmind_skills = collect_skill_dirs(deepmind_dir)
sciagent_skills = collect_skill_dirs(sciagent_dir)
tooluniverse_skills = collect_skill_dirs(tooluniverse_dir)
medical_skills = collect_skill_dirs(medical_dir)
operon_skills = collect_skill_dirs(operon_dir)
lifesci_skills = collect_skill_dirs(lifesci_dir)
bionemo_skills = collect_skill_dirs(bionemo_dir)
naturepaper_skills = collect_skill_dirs(naturepaper_dir)

# Merge all sources (ECC has highest priority on name conflicts)
all_skills = {}
all_skills.update(codex_curated_skills)   # lowest priority
all_skills.update(bioskills)              # bio skills (before clawbio/science/ecc)
all_skills.update(sciagent_skills)       # SciAgent (same level as bioSkills)
all_skills.update(operon_skills)          # operon bioinformatics protocols
all_skills.update(medical_skills)         # medical/clinical skills
all_skills.update(tooluniverse_skills)    # ToolUniverse drug discovery
all_skills.update(lifesci_skills)         # Anthropic life-sciences
all_skills.update(bionemo_skills)         # NVIDIA BioNeMo GPU-accelerated bio
all_skills.update(naturepaper_skills)     # Nature-style manuscript workflow skills
all_skills.update(deepmind_skills)        # DeepMind science skills
all_skills.update(anthropic_skills)       # medium-low priority
all_skills.update(clawbio_skills)         # medium priority
all_skills.update(science_skills)         # medium-high priority
all_skills.update(bipartite_skills)       # bipartite (same level as science)
all_skills.update(ecc_skills)             # highest priority (ECC wins)

# Supplemental: pick up skills that live in ~/.claude/skills/ but aren't
# in any of the source repos. The most common case is K-Dense-authored
# skills that were imported into ~/.claude/skills/ via the Hermes
# openclaw-imports corpus at some earlier point. The ~/.claude-scientific-skills/
# clone is currently empty, so without this step those skills would never
# reach Codex or Pi (which only see skills that flow through all_skills).
# We add them at LOWER priority than all source repos so source skills
# always win on name collision.
claude_extras = {}
claude_skills_dir = os.path.join(home, ".claude", "skills")
if os.path.isdir(claude_skills_dir):
    for skill_md_path in glob.glob(os.path.join(claude_skills_dir, "*", "SKILL.md")):
        # Skip the depth-2 (bioSkills) and depth-3 (archive) entries
        rel = os.path.relpath(skill_md_path, claude_skills_dir)
        if rel.count(os.sep) != 1:
            continue
        skill_name = os.path.basename(os.path.dirname(skill_md_path))
        # Skip dotfile-prefixed and learned skills
        if skill_name.startswith(".") or skill_name == "learned":
            continue
        # Only add if NOT already covered by a source repo (avoid duplicates)
        if skill_name in all_skills:
            continue
        claude_extras[skill_name] = os.path.dirname(skill_md_path)
all_skills.update(claude_extras)            # supplemental (lowest priority)

# =============================================================================
# Prune: make every harness mirror the canonical set EXACTLY. We remove only
# skills WE installed — tracked in a manifest of the previous run's set, plus
# our own symlinks that resolve into an ai-skillweave source root — so each
# harness's NATIVE skills (Codex/Pi built-ins, etc.) are never touched. Skills
# deleted upstream, or belonging to a source we dropped, are removed here
# instead of lingering as orphans.
# =============================================================================
_claude_skills = os.path.join(home, ".claude", "skills")
_hermes_aiweave = os.path.join(home, ".hermes", "skills", "ai-skillweave")
# Dirs ai-skillweave fully owns (only our skills live here) — safe to prune any
# depth-1 skill dir no longer in the set. Codex/Pi mix in native skills, so they
# are pruned only via the manifest + our-symlink rules.
_managed_realcopy = {_claude_skills, openclaw_ws, _hermes_aiweave}
_harness_dirs = [d for d in (_claude_skills, openclaw_ws, pi_skills, codex_skills, _hermes_aiweave) if os.path.isdir(d)]
_manifest_path = os.path.join(home, ".claude", "skills-cache", "sync-manifest.json")
_prev_names = set()
try:
    with open(_manifest_path) as _mf:
        _prev_names = set(json.load(_mf).get("names", []))
except (OSError, ValueError):
    _prev_names = set()
_current_names = set(all_skills)
_source_roots = [os.path.realpath(os.path.join(home, d)) for d in (
    ".claude-everything-claude-code", ".claude-medical-skills", ".claude-operon-skills",
    ".claude-tooluniverse", ".claude-sciagent-skills", ".claude-deepmind-skills",
    ".claude-bionemo-skills", ".claude-clawbio-skills", ".claude-scientific-skills",
    ".claude-bipartite", ".claude-life-sciences", ".claude-curated-skills",
    ".claude-nature-paper-skills",
    os.path.join(".claude", "skills"),
)]

def _is_ours(path):
    try:
        rp = os.path.realpath(path)
    except OSError:
        return False
    return any(rp == r or rp.startswith(r + os.sep) for r in _source_roots)

def _remove_entry(path):
    try:
        if os.path.islink(path) or os.path.isfile(path):
            os.remove(path)
        else:
            shutil.rmtree(path)
        return True
    except OSError:
        return False

_pruned = 0
_no_prune = os.environ.get("ECC_NO_PRUNE") == "1"
for _hdir in ([] if _no_prune else _harness_dirs):
    _is_codex = (_hdir == codex_skills)
    for _entry in os.listdir(_hdir):
        if _entry == "learned" or _entry.startswith("."):
            continue
        # A canonical skill name maps to a (possibly 64-char-truncated) codex dir.
        if _is_codex:
            _keep = any(_entry == n[:64].rstrip("-") for n in _current_names)
        else:
            _keep = _entry in _current_names
        if _keep:
            continue
        _path = os.path.join(_hdir, _entry)
        # Remove only if this is something WE installed:
        #   (a) it was in our previous-run manifest, or
        #   (b) it is a symlink resolving into one of our source roots, or
        #   (c) it lives in a fully-managed real-copy dir (~/.claude/skills, the
        #       OpenClaw workspace, or the Hermes ai-skillweave category) as a
        #       depth-1 dir with its own SKILL.md (bioSkills category dirs have
        #       none → kept).
        _ours = (_entry in _prev_names) or (os.path.islink(_path) and _is_ours(_path))
        if not _ours and _hdir in _managed_realcopy and not os.path.islink(_path):
            _ours = os.path.exists(os.path.join(_path, "SKILL.md"))
        if _ours and _remove_entry(_path):
            _pruned += 1

try:
    os.makedirs(os.path.dirname(_manifest_path), exist_ok=True)
    with open(_manifest_path, "w") as _mf:
        json.dump({"names": sorted(_current_names)}, _mf)
except OSError:
    pass
if _pruned:
    print(f"\033[0;32m[OK]\033[0m Pruned {_pruned} orphaned skill(s) no longer in the source set")

stats = {"openclaw": {"updated": 0, "total": 0}, "pi": {"added": 0, "total": 0}, "codex": {"added": 0, "total": 0}, "hermes": {"updated": 0, "total": 0}}

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
        # Handle case where dst_dir exists as a file (broken previous install)
        if os.path.exists(dst_dir) and not os.path.isdir(dst_dir):
            try:
                os.remove(dst_dir)
            except OSError:
                return False
        os.makedirs(dst_dir, exist_ok=True)
        if needs_sanitize(src):
            with open(dst, "w") as f:
                f.write(sanitize_skill_md(src))
        else:
            shutil.copy2(src, dst)
        return True
    return False

# Codex has a 64-char limit on skill directory names. Truncation would normally
# require rewriting the `name:` field in the SKILL.md frontmatter to match, but
# that breaks cross-harness equivalence (claude, pi, openclaw all see the
# original name; codex would see a different one). Instead we fail loud at the
# pre-flight check (see _preflight_codex_names below) so the offending skill is
# renamed upstream. As a defensive fallback we still truncate the *directory*
# name here so the skill installs in codex with a usable path — but the SKILL.md
# frontmatter is left untouched.
def sync_to_harness_symlink_or_sanitize(skill_name, skill_dir, dest_dir):
    """Sync a skill to harness: symlink if clean YAML, sanitized copy if not.

    For Codex: truncates directory name to 64 chars (Codex limit) but NEVER
    rewrites the `name:` field inside SKILL.md — that would break cross-harness
    equivalence. Pre-flight verification catches over-64 names so this fallback
    should never fire in practice.
    """
    src = os.path.join(skill_dir, "SKILL.md")
    if not os.path.exists(src):
        return False

    # Codex has 64-char limit on skill directory names
    codex_name = skill_name[:64].rstrip("-")
    dst_path = os.path.join(dest_dir, codex_name)

    # Use os.path.lexists (NOT os.path.exists) so we detect broken symlinks
    # too. A broken symlink returns False for exists() (it follows the link)
    # but True for lexists() (it sees the symlink inode). Without this, a
    # prior install's symlink whose target moved/replaced would cause
    # os.symlink() below to raise FileExistsError.
    if os.path.lexists(dst_path):
        # Existing entry at the destination. Check if it's a valid symlink
        # to the same target — if so, no work needed.
        try:
            if os.path.islink(dst_path) and os.path.realpath(dst_path) == os.path.realpath(skill_dir):
                return False
        except OSError:
            pass
        # Otherwise this is a stale entry (broken symlink, real directory
        # from a different source, etc.). Remove and let the sync continue.
        try:
            if os.path.islink(dst_path) or os.path.isfile(dst_path):
                os.remove(dst_path)
            else:
                import shutil as _shutil
                _shutil.rmtree(dst_path)
        except OSError:
            return False  # can't recover; skip this skill

    if needs_sanitize(src):
        os.makedirs(dst_path, exist_ok=True)
        # NOTE: deliberately NOT rewriting the `name:` field. The skill
        # keeps its original name in SKILL.md even if the directory is
        # truncated — this preserves cross-harness equivalence.
        content = sanitize_skill_md(src)
        with open(os.path.join(dst_path, "SKILL.md"), "w") as f:
            f.write(content)
    else:
        os.symlink(skill_dir, dst_path)
    return True


# Pre-flight: list any skills whose names would trigger codex truncation. This
# is informational (not a hard error) so installs continue, but it surfaces the
# latent bug to the user/operator before silent truncation happens.
def _preflight_codex_names(all_skills_map):
    over = [(n, p) for n, p in all_skills_map.items() if len(n) > 64]
    if over:
        print("\033[1;33m[ECC][WARN]\033[0m {} skill(s) exceed Codex's 64-char directory name limit:".format(len(over)))
        for n, p in over:
            print("\033[1;33m[ECC][WARN]\033[0m   - {!r} ({} chars) — directory will be truncated, SKILL.md name: field preserved".format(n, len(n)))
    return len(over)

# --- OpenClaw: real file copies (sanitized) for all skill sources ---
if os.path.isdir(os.path.join(home, ".openclaw", "workspace")):
    os.makedirs(openclaw_ws, exist_ok=True)
    for skill_name, skill_dir in all_skills.items():
        if sync_to_harness_real(skill_name, skill_dir, openclaw_ws):
            stats["openclaw"]["updated"] += 1
    stats["openclaw"]["total"] = len([d for d in os.listdir(openclaw_ws) if os.path.isdir(os.path.join(openclaw_ws, d))])

# --- Pi: symlinks for all skill sources ---
# Use os.path.lexists (NOT os.path.exists) so we detect broken symlinks
# and replace them. A broken symlink returns False for exists() (it follows
# the link) but True for lexists() (it sees the symlink inode). Without
# this, a prior install's symlink whose target moved/replaced would cause
# os.symlink() below to raise FileExistsError.
if os.path.isdir(os.path.join(home, ".pi", "agent")):
    os.makedirs(pi_skills, exist_ok=True)
    for skill_name, skill_dir in all_skills.items():
        target = os.path.join(pi_skills, skill_name)
        if os.path.lexists(target):
            # Entry exists. Check if it's a valid symlink to the same target
            # — if so, no work needed.
            try:
                if os.path.islink(target) and os.path.realpath(target) == os.path.realpath(skill_dir):
                    continue
            except OSError:
                pass
            # Otherwise this is a stale entry (broken symlink, real dir from
            # a different source, etc.). Remove and let the sync continue.
            try:
                os.remove(target)
            except OSError:
                continue  # can't remove; skip this skill
        try:
            os.symlink(skill_dir, target)
            stats["pi"]["added"] += 1
        except (OSError, FileExistsError):
            pass  # Skip if symlink fails for any other reason
    stats["pi"]["total"] = len(os.listdir(pi_skills))

# --- Codex: symlinks where clean, sanitized copies where needed ---
# Pre-flight: warn (but don't fail) about any over-64-char names so the user
# knows which skills will be silently directory-truncated.
_preflight_codex_names(all_skills)
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
        # Check if dst_dir exists as a symlink (from cross-harness linking)
        if os.path.islink(dst_dir):
            # Check if symlink is broken (target doesn't exist)
            if not os.path.exists(dst_dir):
                # Broken symlink — remove and recreate as valid symlink
                try:
                    os.remove(dst_dir)
                    os.symlink(skill_dir, dst_dir)
                except OSError:
                    continue  # Skip if removal/recreation fails
                claude_updated += 1
                continue
            # Valid symlink — copy SKILL.md into the symlinked directory
            if os.path.exists(dst) and src_mtime <= os.path.getmtime(dst):
                continue  # Already up to date
            shutil.copy2(src, dst)
            claude_updated += 1
            continue
        # Regular directory case
        if os.path.exists(dst) and src_mtime <= os.path.getmtime(dst):
            continue  # Already up to date
        os.makedirs(dst_dir, exist_ok=True)
        shutil.copy2(src, dst)
        claude_updated += 1
    # Also sync learned skills (flat .md in learned/ subdir — leave as-is)
    claude_total = len([d for d in os.listdir(claude_skills)
                        if os.path.isdir(os.path.join(claude_skills, d)) and d != "learned"])
    if migrated > 0:
        print(f"\033[0;32m[OK]\033[0m Claude Code: migrated {migrated} flat .md skills to directory format")
    print(f"\033[0;32m[OK]\033[0m Claude Code: {claude_total} skills ({claude_updated} updated)")

# --- Hermes: real file copies into a dedicated ~/.hermes/skills/ai-skillweave/
# category. Hermes auto-discovers <category>/<skill>/SKILL.md, so the whole pool
# lands under one "ai-skillweave" toolset; native Hermes toolsets and the
# openclaw-imports staging set are left untouched.
hermes_skills_root = os.path.join(home, ".hermes", "skills")
if os.path.isdir(hermes_skills_root):
    hermes_aiweave = os.path.join(hermes_skills_root, "ai-skillweave")
    os.makedirs(hermes_aiweave, exist_ok=True)
    for skill_name, skill_dir in all_skills.items():
        if sync_to_harness_real(skill_name, skill_dir, hermes_aiweave):
            stats["hermes"]["updated"] += 1
    stats["hermes"]["total"] = len([d for d in os.listdir(hermes_aiweave)
                                    if os.path.isdir(os.path.join(hermes_aiweave, d))])

total = len(all_skills)
print(f"\033[0;32m[OK]\033[0m All skill sources: ECC({len(ecc_skills)}) + Anthropic({len(anthropic_skills)}) + Codex curated({len(codex_curated_skills)}) + K-Dense({len(science_skills)}) + ClawBio({len(clawbio_skills)}) + bioSkills({len(bioskills)}) + Bipartite({len(bipartite_skills)}) + DeepMind({len(deepmind_skills)}) + SciAgent({len(sciagent_skills)}) + ToolUniverse({len(tooluniverse_skills)}) + Medical({len(medical_skills)}) + operon({len(operon_skills)}) + life-sciences({len(lifesci_skills)}) + BioNeMo({len(bionemo_skills)}) + NaturePaper({len(naturepaper_skills)}) = {total} unique skill dirs")
print(f"\033[0;32m[OK]\033[0m OpenClaw: {stats['openclaw']['total']} skills ({stats['openclaw']['updated']} updated)")
print(f"\033[0;32m[OK]\033[0m Pi: {stats['pi']['total']} skills ({stats['pi']['added']} new)")
print(f"\033[0;32m[OK]\033[0m Codex: {stats['codex']['total']} skills ({stats['codex']['added']} new — includes native Codex skills)")
print(f"\033[0;32m[OK]\033[0m Hermes: {stats['hermes']['total']} ai-skillweave skills ({stats['hermes']['updated']} updated) in ~/.hermes/skills/ai-skillweave/")
PYEOF

echo ""
success "ECC update complete! Restart Claude Code and OpenClaw to load new skills."

# =============================================================================
# Step 4: Run learning pipeline (extract + sync learned skills)
# =============================================================================

# Prevent duplicate pipeline runs within 3 days (e.g. repeated installs,
# overlapping cron jobs). The LLM distillation is expensive (3-5 min on
# a 23GB thinking model) and re-running it within a few days produces
# the same skills from the same conversation histories.
LOCK_FILE="/tmp/ai-skillweave-learn.lock"
LOCK_MAX_AGE=$((3 * 24 * 60 * 60))  # 3 days — prevents redundant LLM runs

should_run_learning=true
if [ -f "$LOCK_FILE" ]; then
    lock_age=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0)))
    if [ "$lock_age" -lt "$LOCK_MAX_AGE" ]; then
        lock_age_h=$((lock_age / 3600))
        # Show learned skill count so the user knows what's already there
        LEARNED_DIR="$HOME/.claude/skills/learned"
        LEARNED_COUNT=$(ls "$LEARNED_DIR"/*.md 2>/dev/null | grep -v '/.usage' | wc -l | tr -d ' ')
        log "Learning pipeline already ran ${lock_age_h}h ago (within 3-day window) — skipping ($LEARNED_COUNT learned skills already present)"
        should_run_learning=false
    fi
fi

if $should_run_learning; then
    touch "$LOCK_FILE"
    SYNC_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sync-learned-skills.sh"
    if [ -f "$SYNC_SCRIPT" ]; then
        SYNC_ARGS=""
        [[ "$*" == *"--no-llm"* ]] && SYNC_ARGS="$SYNC_ARGS --no-llm"
        log "Running learning pipeline..."
        bash "$SYNC_SCRIPT" $SYNC_ARGS && success "Learned skills synced" || warn "Learning pipeline had issues (non-fatal)"
    else
        warn "sync-learned-skills.sh not found — skipping learned skill extraction"
    fi
fi

echo ""
