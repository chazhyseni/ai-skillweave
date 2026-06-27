#!/bin/bash
# =============================================================================
# setup-copilot-skills.sh — Wire Copilot CLI to the cross-harness skill pool
# =============================================================================
# Bridges GitHub Copilot CLI to the same ~2,500 SKILL.md files already
# delivered to Claude/Codex/OpenClaw/Pi by safe-install.sh + update-ecc.sh.
#
# How Copilot CLI 1.0.65 actually discovers skills (from the app.js source):
#
#   • Project: .github/skills/, .agents/skills/, or .claude/skills/  (CWD only)
#   • Personal: ~/.copilot/skills/  or  ~/.agents/skills/
#   • Custom: directories added via Copilot's own `/skills add` slash command
#             (persists in settings.json under the skillDirectories key)
#
# There is NO `~/.copilot/config/skills` discovery path and NO
# COPILOT_SKILLS_DIRS env var — earlier versions of this script pointed at
# both, which is why macOS sometimes worked (path coincidentally existed) but
# Linux silently loaded zero skills (Copilot never looked at those paths).
#
# What this script does:
#   1. Symlink ~/.copilot/skills/ -> ~/.claude/skills/. Zero duplication,
#      instant sync — every skill update in ~/.claude/skills/ is visible to
#      Copilot on next launch with no extra work. This is the personal-copilot
#      discovery root that GitHub Copilot CLI actually scans.
#   2. Sanitize any SKILL.md in ~/.claude/skills/ whose frontmatter uses a
#      block-scalar description (`description: >` or `|`). Copilot's loader
#      is line-oriented and rejects those with "missing or malformed YAML
#      frontmatter". Sanitization is idempotent — clean files are skipped.
#      safe-install.sh and update-ecc.sh also sanitize at install/sync time;
#      this sweep is the backstop for skills installed before the guard.
#
# Idempotent: re-running this script is safe and updates the symlink atomically.
#
# Usage:
#   scripts/setup-copilot-skills.sh           # apply (default)
#   scripts/setup-copilot-skills.sh --check    # verify only, no changes
#   scripts/setup-copilot-skills.sh --unlink   # remove symlink and restore
#                                              # any pre-existing real dir
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COPILOT_DIR="$HOME/.copilot"
COPILOT_SKILLS_LINK="$COPILOT_DIR/skills"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
log()     { echo -e "${BLUE}[COPILOT-SKILLS]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

ACTION="apply"
for arg in "$@"; do
    case $arg in
        --check)  ACTION="check" ;;
        --unlink) ACTION="unlink" ;;
        --help|-h)
            sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# //;s/^#//'
            exit 0
            ;;
    esac
done

# --- Sanity checks ---
[ -d "$CLAUDE_SKILLS_DIR" ] || error "Claude skills dir not found: $CLAUDE_SKILLS_DIR — run ./safe-install.sh first"
command -v copilot >/dev/null 2>&1 || warn "Copilot CLI not on PATH — install with: npm install -g @github/copilot"

# --- Sweep stale block-scalar frontmatter in every SKILL.md reachable
# via Copilot's personal-skills path ---
# `~/.copilot/skills/` is symlinked to `~/.claude/skills/`, which
# contains ~1,400 individual symlinks pointing into per-source dirs
# (e.g. `~/.claude-medical-skills/skills/<name>/`, `~/.claude-operon-
# skills/protocols/<name>/`, etc.). The non-recursive `glob('*/*.md')`
# sweep only catches the top-level entries; we need a recursive walker
# that follows symlinks to sanitize every file Copilot will actually
# see. Each unique real path is sanitized at most once (deduped by
# `os.path.realpath`).
log "Sweeping Copilot-incompatible frontmatter across all reachable skills..."
sweep_output=$(python3 - << 'PYEOF' 2>&1
import sys, os, glob
sys.path.insert(0, "/home/chaz/scripts/ai-skillweave/scripts")
from skill_sanitize import needs_sanitize_for_copilot, sanitize_skill_md

COPILOT_DIR = os.path.expanduser("~/.copilot/skills")
real_files = set()
def walk(dir):
    try:
        for entry in os.listdir(dir):
            full = os.path.join(dir, entry)
            if os.path.islink(full):
                target = os.readlink(full)
                if not os.path.isabs(target):
                    target = os.path.join(dir, target)
                if os.path.isdir(target):
                    walk(target)
                elif entry == 'SKILL.md' and os.path.isfile(target):
                    real_files.add(os.path.realpath(target))
            elif os.path.isdir(full):
                walk(full)
            elif entry == 'SKILL.md' and os.path.isfile(full):
                real_files.add(os.path.realpath(full))
    except (PermissionError, FileNotFoundError):
        pass

walk(COPILOT_DIR)
unique = sorted(real_files)
fixed = 0
errors = []
for p in unique:
    if needs_sanitize_for_copilot(p):
        try:
            new = sanitize_skill_md(p)
            orig_body = open(p).read().split("---", 2)[2]
            new_body = new.split("---", 2)[2]
            if abs(len(orig_body) - len(new_body)) > 4:
                errors.append(f"body length changed by {len(new_body) - len(orig_body)} bytes: {p}")
                continue
            with open(p, "w") as f:
                f.write(new)
            fixed += 1
        except Exception as e:
            errors.append(f"{p}: {e}")
print(f"swept {len(unique)} skills, sanitized {fixed}")
if errors:
    print("errors:")
    for e in errors[:5]:
        print(f"  {e}")
PYEOF
)
echo "$sweep_output" | while IFS= read -r line; do
    if [[ "$line" == *"errors:"* ]] || [[ "$line" == *"  "* ]]; then
        warn "$line"
    elif [ -n "$line" ]; then
        success "$line"
    fi
done

# === Check-only mode ===
if [ "$ACTION" = "check" ]; then
    log "Verifying Copilot skill bridge..."
    if [ -L "$COPILOT_SKILLS_LINK" ] && [ "$(readlink "$COPILOT_SKILLS_LINK")" = "$CLAUDE_SKILLS_DIR" ]; then
        success "Symlink OK: $COPILOT_SKILLS_LINK -> $CLAUDE_SKILLS_DIR"
    elif [ -L "$COPILOT_SKILLS_LINK" ]; then
        warn "Symlink exists but points to $(readlink "$COPILOT_SKILLS_LINK") (expected $CLAUDE_SKILLS_DIR)"
    elif [ -d "$COPILOT_SKILLS_LINK" ]; then
        warn "$COPILOT_SKILLS_LINK is a real directory (not a symlink) — run without --check to fix"
    else
        warn "No symlink at $COPILOT_SKILLS_LINK — Copilot will not find Claude skills natively"
    fi
    # Read-test: pick any SKILL.md and confirm the symlink resolves to readable content
    sample=$(find "$CLAUDE_SKILLS_DIR" -name SKILL.md -not -path "*/learned/*" 2>/dev/null | head -1)
    if [ -n "$sample" ]; then
        rel="${sample#$CLAUDE_SKILLS_DIR/}"
        rel="${rel%/SKILL.md}"
        copilot_via_link="$COPILOT_SKILLS_LINK/$rel/SKILL.md"
        if [ -f "$copilot_via_link" ]; then
            success "Read-test passed: $rel resolves to readable SKILL.md via $COPILOT_SKILLS_LINK"
        else
            warn "Read-test FAILED: $rel not accessible via $COPILOT_SKILLS_LINK"
        fi
    fi
    # YAML frontmatter check: count SKILL.md files that would still be rejected
    # by Copilot CLI's `promptsParseFrontmatter` addon. Walk recursively
    # and follow symlinks (some of the per-source dirs are reached via
    # individual symlinks inside ~/.claude/skills/).
    bad_count=$(REPO_DIR="$REPO_DIR" python3 - << 'PYEOF' 2>/dev/null
import sys, os
sys.path.insert(0, os.environ.get("REPO_DIR", "/home/chaz/scripts/ai-skillweave") + "/scripts")
from skill_sanitize import needs_sanitize_for_copilot

COPILOT_DIR = os.path.expanduser("~/.copilot/skills")
real_files = set()
def walk(d):
    try:
        for entry in os.listdir(d):
            full = os.path.join(d, entry)
            if os.path.islink(full):
                target = os.readlink(full)
                if not os.path.isabs(target):
                    target = os.path.join(d, target)
                if os.path.isdir(target):
                    walk(target)
                elif entry == 'SKILL.md' and os.path.isfile(target):
                    real_files.add(os.path.realpath(target))
            elif os.path.isdir(full):
                walk(full)
            elif entry == 'SKILL.md' and os.path.isfile(full):
                real_files.add(os.path.realpath(full))
    except (PermissionError, FileNotFoundError):
        pass

walk(COPILOT_DIR)
print(sum(1 for p in real_files if needs_sanitize_for_copilot(p)))
PYEOF
)
    if [ "$bad_count" = "0" ]; then
        success "YAML check: 0 skills rejected by Copilot's frontmatter parser"
    else
        warn "YAML check: $bad_count skills still have Copilot-incompatible frontmatter (run without --check to auto-sanitize)"
    fi
    exit 0
fi

# === Unlink mode ===
if [ "$ACTION" = "unlink" ]; then
    log "Removing Copilot skill bridge..."
    if [ -L "$COPILOT_SKILLS_LINK" ]; then
        rm "$COPILOT_SKILLS_LINK"
        success "Removed symlink: $COPILOT_SKILLS_LINK"
    elif [ -d "$COPILOT_SKILLS_LINK" ]; then
        warn "$COPILOT_SKILLS_LINK is a real directory (not a symlink) — leaving it in place"
        warn "To remove manually: rm -rf $COPILOT_SKILLS_LINK"
    else
        log "No symlink or directory at $COPILOT_SKILLS_LINK"
    fi
    # Also clean up the COPILOT_SKILLS_DIRS export and _copilot_with_skills
    # wrapper if the user installed an earlier version of this script that
    # added them. Both are no-ops since COPILOT_SKILLS_DIRS is not a real
    # Copilot discovery path (verified against the app.js source).
    case "${SHELL##*/}" in
        zsh)  SHELL_RC="$HOME/.zshrc" ;;
        bash) SHELL_RC="$HOME/.bashrc" ;;
        *)    SHELL_RC="$HOME/.bashrc" ;;
    esac
    if [ -f "$SHELL_RC" ]; then
        for marker in \
            '^export COPILOT_SKILLS_DIRS=' \
            '^_copilot_with_skills\(\) \{' \
            '^alias copilot='\''_copilot_with_skills'\''' \
            '^alias copilot=_copilot_with_skills'; do
            if grep -qE "$marker" "$SHELL_RC" 2>/dev/null; then
                grep -vE "$marker" "$SHELL_RC" > "$SHELL_RC.tmp" && mv "$SHELL_RC.tmp" "$SHELL_RC"
                success "Removed obsolete Copilot config from $SHELL_RC (matched: $marker)"
            fi
        done
    fi
    echo ""
    success "Uninstall complete. Existing real skills at $COPILOT_SKILLS_LINK are untouched."
    exit 0
fi

# === Apply mode (default) ===
log "Wiring Copilot CLI to cross-harness skill pool..."

# Step 1: create the symlink atomically
mkdir -p "$COPILOT_DIR"
if [ -e "$COPILOT_SKILLS_LINK" ] && [ ! -L "$COPILOT_SKILLS_LINK" ]; then
    # Real directory exists — back it up and replace with symlink. This
    # protects any skills the user has created directly in ~/.copilot/skills/
    # (e.g. via Copilot's own `/skills add` slash command). Their content is
    # preserved as ~/.copilot/skills.pre-skillweave-<timestamp>/, and they
    # take precedence over Claude skills because Copilot loads ~/.copilot/skills/
    # last.
    backup="$COPILOT_SKILLS_LINK.pre-skillweave-$(date +%Y%m%d_%H%M%S)"
    warn "Existing non-symlink at $COPILOT_SKILLS_LINK — backing up to $backup"
    warn "(this preserves any skills you added via Copilot's /skills add command)"
    mv "$COPILOT_SKILLS_LINK" "$backup"
fi
# Use ln -sfn (force + no-dereference) so the operation is idempotent.
# Force is required because an existing broken symlink would otherwise fail.
ln -sfn "$CLAUDE_SKILLS_DIR" "$COPILOT_SKILLS_LINK"
success "Symlink: $COPILOT_SKILLS_LINK -> $CLAUDE_SKILLS_DIR"

# Step 2: read-test to confirm the bridge actually works end-to-end
log "Verifying read access via Copilot's personal-skills path..."
sample=$(find "$CLAUDE_SKILLS_DIR" -name SKILL.md -not -path "*/learned/*" 2>/dev/null | head -1)
if [ -n "$sample" ]; then
    rel="${sample#$CLAUDE_SKILLS_DIR/}"
    rel="${rel%/SKILL.md}"
    copilot_via_link="$COPILOT_SKILLS_LINK/$rel/SKILL.md"
    if [ -f "$copilot_via_link" ]; then
        success "Read-test passed: Copilot will find $rel via $COPILOT_SKILLS_LINK"
    else
        warn "Read-test soft-fail: $rel not directly accessible (may still resolve at runtime via symlink)"
    fi
fi

# Count what we're bridging
claude_count=$(find "$CLAUDE_SKILLS_DIR" -name SKILL.md -not -path "*/learned/*" 2>/dev/null | wc -l | tr -d ' ')
echo ""
success "Bridge installed: $claude_count skills from Claude visible to Copilot"
log "Restart Copilot CLI: any active session must be reloaded (Ctrl-C and re-launch)."
