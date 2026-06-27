#!/bin/bash
# =============================================================================
# setup-copilot-skills.sh — Wire Copilot CLI to the cross-harness skill pool
# =============================================================================
# Bridges GitHub Copilot CLI (which has no native skill installer) to the same
# ~900 SKILL.md files already delivered to Claude/Codex/OpenClaw/Pi by
# safe-install.sh + update-ecc.sh.
#
# Two complementary mechanisms:
#   1. Symlink ~/.copilot/config/skills -> ~/.claude/skills (zero duplication,
#      instant sync, picks up every skill change automatically).
#   2. Set COPILOT_SKILLS_DIRS in the user's shell rc to include both
#      ~/.claude/skills and ~/.pi/agent/skills. This is what Copilot's own
#      loader reads on startup (per the Copilot CLI source — it also reads
#      .github/skills, .agents/skills, ~/.copilot/config/skills, and the env
#      var COPILOT_SKILLS_DIRS for additional paths).
#
# Why both? The symlink guarantees Copilot finds the canonical skill tree
# under its own config dir. The env var makes the discovery order explicit
# and covers harnesses that look for skills by name before the symlink is
# resolved.
#
# YAML frontmatter sweep: every run also walks ~/.claude/skills and
# flattens any `description: >` block-scalar frontmatter (Copilot CLI's
# line-oriented parser rejects those with "missing or malformed YAML
# frontmatter"). Idempotent — clean files are skipped. The same
# sanitization happens inside safe-install.sh on every fresh skill copy,
# so this sweep is the backstop for skills installed before the guard.
#
# Idempotent: re-running this script is safe and updates the symlink atomically.
#
# Usage:
#   scripts/setup-copilot-skills.sh           # apply (default)
#   scripts/setup-copilot-skills.sh --check    # verify only, no changes
#   scripts/setup-copilot-skills.sh --unlink   # remove symlink and env-var line
# =============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COPILOT_DIR="$HOME/.copilot"
COPILOT_SKILLS_LINK="$COPILOT_DIR/config/skills"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
PI_SKILLS_DIR="$HOME/.pi/agent/skills"

# Detect user's login shell for RC file selection (matches install.sh logic)
case "${SHELL##*/}" in
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    bash) SHELL_RC="$HOME/.bashrc" ;;
    *)    SHELL_RC="$HOME/.bashrc" ;;
esac

# Build the canonical COPILOT_SKILLS_DIRS value from the directories that
# actually exist. Skipping missing dirs is the same behavior Copilot itself
# uses (it logs a warning and continues), so no harm in doing it here too.
SKILLS_DIRS=()
[ -d "$CLAUDE_SKILLS_DIR" ] && SKILLS_DIRS+=("$CLAUDE_SKILLS_DIR")
[ -d "$PI_SKILLS_DIR" ]    && SKILLS_DIRS+=("$PI_SKILLS_DIR")
COPILOT_SKILLS_DIRS_VALUE=$(IFS=: ; echo "${SKILLS_DIRS[*]}")

ACTION="apply"
for arg in "$@"; do
    case $arg in
        --check)  ACTION="check" ;;
        --unlink) ACTION="unlink" ;;
        --help|-h)
            sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# //;s/^#//'
            exit 0
            ;;
    esac
done

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
log()     { echo -e "${BLUE}[COPILOT-SKILLS]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Sanity checks ---
[ -d "$CLAUDE_SKILLS_DIR" ] || error "Claude skills dir not found: $CLAUDE_SKILLS_DIR — run ./safe-install.sh first"
command -v copilot >/dev/null 2>&1 || warn "Copilot CLI not on PATH — install with: npm install -g @github/copilot"

# --- Sweep stale block-scalar frontmatter in ~/.claude/skills ---
# This handles skills that were installed before the sanitization guard was
# added to safe-install.sh. Idempotent: needs_sanitize_for_copilot() returns
# False for clean files, so this is a no-op on every subsequent run.
log "Sweeping block-scalar frontmatter in Claude skills tree..."
sweep_output=$(python3 - << 'PYEOF' 2>&1
import sys, os, glob
sys.path.insert(0, os.environ.get("REPO_DIR", "") + "/scripts")
from skill_sanitize import needs_sanitize_for_copilot, sanitize_skill_md
top = glob.glob(os.path.expanduser("~/.claude/skills/*/SKILL.md"))
unique = list({os.path.realpath(p): p for p in top}.values())
fixed = 0
errors = []
for p in unique:
    if needs_sanitize_for_copilot(p):
        try:
            new = sanitize_skill_md(p)
            orig_body = open(p).read().split("---", 2)[2]
            new_body = new.split("---", 2)[2]
            if len(orig_body) != len(new_body):
                errors.append(f"body length changed: {p}")
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
    else
        warn "No symlink at $COPILOT_SKILLS_LINK — Copilot will not find Claude skills natively"
    fi
    if [ -f "$SHELL_RC" ] && grep -qE '^export COPILOT_SKILLS_DIRS=' "$SHELL_RC" 2>/dev/null; then
        success "COPILOT_SKILLS_DIRS export found in $SHELL_RC"
    else
        warn "COPILOT_SKILLS_DIRS not set in $SHELL_RC"
    fi
    # Read-test: pick any SKILL.md and confirm the symlink resolves to readable content
    sample=$(find "$CLAUDE_SKILLS_DIR" -name SKILL.md -not -path "*/learned/*" 2>/dev/null | head -1)
    if [ -n "$sample" ]; then
        # Resolve the symlink path: if a skill was synced to claude, then under
        # the copilot symlink it should be the same file (resolved by realpath).
        rel="${sample#$CLAUDE_SKILLS_DIR/}"
        rel="${rel%/SKILL.md}"
        copilot_via_link="$COPILOT_SKILLS_LINK/$rel/SKILL.md"
        if [ -f "$copilot_via_link" ]; then
            success "Read-test passed: $rel resolves to readable SKILL.md via Copilot's config dir"
        else
            warn "Read-test FAILED: $rel not accessible via $COPILOT_SKILLS_LINK"
        fi
    fi
    # YAML frontmatter check: count SKILL.md files that would still be rejected
    # by Copilot CLI's line-oriented parser (block-scalar descriptions).
    bad_count=$(python3 - << 'PYEOF' 2>/dev/null
import sys, os, glob
sys.path.insert(0, os.environ.get("REPO_DIR", "") + "/scripts")
from skill_sanitize import needs_sanitize_for_copilot
top = glob.glob(os.path.expanduser("~/.claude/skills/*/SKILL.md"))
unique = list({os.path.realpath(p): p for p in top}.values())
print(sum(1 for p in unique if needs_sanitize_for_copilot(p)))
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
    else
        log "No symlink to remove at $COPILOT_SKILLS_LINK"
    fi
    if [ -f "$SHELL_RC" ]; then
        if grep -qE '^export COPILOT_SKILLS_DIRS=' "$SHELL_RC" 2>/dev/null; then
            # Remove only the line we wrote (matches both initial install and re-runs)
            grep -v -E '^export COPILOT_SKILLS_DIRS=' "$SHELL_RC" > "$SHELL_RC.tmp" \
                && mv "$SHELL_RC.tmp" "$SHELL_RC"
            success "Removed COPILOT_SKILLS_DIRS export from $SHELL_RC"
        else
            log "No COPILOT_SKILLS_DIRS export to remove in $SHELL_RC"
        fi
    fi
    echo ""
    success "Uninstall complete. Reload shell: source $SHELL_RC"
    exit 0
fi

# === Apply mode (default) ===
log "Wiring Copilot CLI to cross-harness skill pool..."

# Step 1: create the symlink atomically
mkdir -p "$COPILOT_DIR/config"
if [ -e "$COPILOT_SKILLS_LINK" ] && [ ! -L "$COPILOT_SKILLS_LINK" ]; then
    # Real directory exists — back it up and replace with symlink. This shouldn't
    # happen on a fresh install but is defensive against a previous broken state.
    backup="$COPILOT_SKILLS_LINK.pre-skillweave-$(date +%Y%m%d_%H%M%S)"
    warn "Existing non-symlink at $COPILOT_SKILLS_LINK — backing up to $backup"
    mv "$COPILOT_SKILLS_LINK" "$backup"
fi
# Use ln -sfn (force + no-dereference) so the operation is idempotent
ln -sfn "$CLAUDE_SKILLS_DIR" "$COPILOT_SKILLS_LINK"
success "Symlink: $COPILOT_SKILLS_LINK -> $CLAUDE_SKILLS_DIR"

# Step 2: append COPILOT_SKILLS_DIRS to user's shell rc (idempotent — checks for
# the actual export line, not the comment that documents it, so re-runs don't
# double-append even if the comment is still there from a previous version).
if [ -f "$SHELL_RC" ] && grep -qE '^export COPILOT_SKILLS_DIRS=' "$SHELL_RC" 2>/dev/null; then
    log "COPILOT_SKILLS_DIRS already configured in $SHELL_RC (skipping)"
else
    # Touch the rc file if it doesn't exist
    [ -f "$SHELL_RC" ] || touch "$SHELL_RC"
    cat >> "$SHELL_RC" << EOF

# ai-skillweave: copilot skills — points Copilot CLI at the cross-harness skill pool
export COPILOT_SKILLS_DIRS="$COPILOT_SKILLS_DIRS_VALUE"
EOF
    success "Added COPILOT_SKILLS_DIRS export to $SHELL_RC"
fi

# Step 2b: refresh the _copilot_with_skills() function in the user's rc to
# match the current safe-install.sh version. This is needed because the
# pre-fix wrapper in older installs was a no-op passthrough that didn't set
# COPILOT_SKILLS_DIRS inline — so even if the env-var line above is added,
# the existing function call would still launch copilot without it. The
# marker comment anchors the in-place replacement so we don't clobber
# unrelated edits.
FUNC_MARKER="# ai-skillweave:copilot-fn-begin"
FUNC_END_MARKER="# ai-skillweave:copilot-fn-end"
if [ -f "$SHELL_RC" ] && grep -qF "$FUNC_MARKER" "$SHELL_RC"; then
    # Replace the existing marked block in place
    log "Refreshing _copilot_with_skills() function in $SHELL_RC (in-place)..."
    python3 - "$SHELL_RC" "$FUNC_MARKER" "$FUNC_END_MARKER" << 'PYEOF'
import sys, pathlib
rc_path, begin_marker, end_marker = sys.argv[1], sys.argv[2], sys.argv[3]
new_block = '''_copilot_with_skills() {
    # ai-skillweave:copilot-fn-begin  (do not edit this marker — setup-copilot-skills.sh refreshes it)
    # Copilot CLI natively discovers SKILL.md files from:
    #   1. ~/.claude/skills/ (read as the 'personal-claude' source)
    #   2. ~/.copilot/config/skills/ (read as 'copilot-config' — symlinked to ~/.claude/skills by setup-copilot-skills.sh)
    #   3. ~/.agents/skills/ (Agent Skills spec standard path)
    #   4. .github/skills/ and .agents/skills/ inside the current project
    #   5. Any path in COPILOT_SKILLS_DIRS (colon-separated, like PATH)
    (unset SKILLS_CONTENT CODEX_SYSTEM_PROMPT OPENCLAW_SYSTEM_PROMPT
     if [ -z "${COPILOT_SKILLS_DIRS:-}" ]; then
         local _dirs=""
         [ -d "$HOME/.claude/skills" ] && _dirs="$HOME/.claude/skills"
         [ -d "$HOME/.pi/agent/skills" ] && _dirs="${_dirs:+$_dirs:}$HOME/.pi/agent/skills"
         [ -n "$_dirs" ] && export COPILOT_SKILLS_DIRS="$_dirs"
     fi
     command copilot "$@")
    # ai-skillweave:copilot-fn-end
}'''
text = pathlib.Path(rc_path).read_text()
# Find the begin/end markers and replace the block between them
b = text.find(begin_marker)
if b < 0:
    sys.exit(0)  # no marker, nothing to refresh
e = text.find(end_marker, b)
if e < 0:
    sys.exit(0)
e += len(end_marker)
# Find the enclosing "function header" line (i.e. the line starting with
# "_copilot_with_skills() {") and replace from that line to just after the
# end marker (including the closing brace on the next line).
# Walk back to find the function definition line.
start = text.rfind('\n_copilot_with_skills()', 0, b)
if start < 0:
    start = b  # fallback
# Walk forward to find the closing brace on the line after the end marker.
end_of_block = text.find('\n}\n', e)
if end_of_block < 0:
    end_of_block = text.find('\n}', e)
if end_of_block < 0:
    end_of_block = e
end_of_block = end_of_block + len('\n}')
new_text = text[:start] + '\n' + new_block + text[end_of_block:]
pathlib.Path(rc_path).write_text(new_text)
PYEOF
    success "Refreshed _copilot_with_skills() in $SHELL_RC"
elif [ -f "$SHELL_RC" ] && grep -qE '^_copilot_with_skills\(\) \{' "$SHELL_RC"; then
    # Pre-existing function without our marker — replace it once with the
    # marked version so future re-runs can refresh it in place. The pre-fix
    # version was a no-op passthrough; this upgrade is the path that
    # actually moves users onto the new behavior without requiring a
    # full re-run of safe-install.sh.
    log "Found pre-existing _copilot_with_skills() in $SHELL_RC — upgrading to marked version..."
    python3 - "$SHELL_RC" << 'PYEOF'
import sys, pathlib, re
rc_path = sys.argv[1]
new_block = '''_copilot_with_skills() {
    # ai-skillweave:copilot-fn-begin  (do not edit this marker — setup-copilot-skills.sh refreshes it)
    # Copilot CLI natively discovers SKILL.md files from:
    #   1. ~/.claude/skills/ (read as the 'personal-claude' source)
    #   2. ~/.copilot/config/skills/ (read as 'copilot-config' — symlinked to ~/.claude/skills by setup-copilot-skills.sh)
    #   3. ~/.agents/skills/ (Agent Skills spec standard path)
    #   4. .github/skills/ and .agents/skills/ inside the current project
    #   5. Any path in COPILOT_SKILLS_DIRS (colon-separated, like PATH)
    (unset SKILLS_CONTENT CODEX_SYSTEM_PROMPT OPENCLAW_SYSTEM_PROMPT
     if [ -z "${COPILOT_SKILLS_DIRS:-}" ]; then
         local _dirs=""
         [ -d "$HOME/.claude/skills" ] && _dirs="$HOME/.claude/skills"
         [ -d "$HOME/.pi/agent/skills" ] && _dirs="${_dirs:+$_dirs:}$HOME/.pi/agent/skills"
         [ -n "$_dirs" ] && export COPILOT_SKILLS_DIRS="$_dirs"
     fi
     command copilot "$@")
    # ai-skillweave:copilot-fn-end
}'''
text = pathlib.Path(rc_path).read_text()
# Match the entire old function: from a line that starts with
# "_copilot_with_skills() {" through the next line that is exactly "}"
pattern = re.compile(r'^_copilot_with_skills\(\) \{.*?\n\}\n?', re.MULTILINE | re.DOTALL)
new_text, n = pattern.subn(new_block + '\n', text)
if n == 0:
    # Fallback: maybe the function is on a single line. Try a narrower match.
    pattern = re.compile(r'^_copilot_with_skills\(\) \{.*?\}\n?', re.MULTILINE | re.DOTALL)
    new_text, n = pattern.subn(new_block + '\n', text)
if n > 0:
    pathlib.Path(rc_path).write_text(new_text)
    print(f"Replaced {n} occurrence(s) of _copilot_with_skills()")
else:
    print("WARN: could not find function body to replace (unexpected)")
PYEOF
    success "Upgraded pre-existing _copilot_with_skills() in $SHELL_RC to marked version"
fi

# Step 3: read-test to confirm the bridge actually works end-to-end
log "Verifying read access via Copilot's config path..."
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
pi_count=$(find "$PI_SKILLS_DIR" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
echo ""
success "Bridge installed: $claude_count skills from Claude + $pi_count from Pi visible to Copilot"
log "Reload shell: source $SHELL_RC"
log "Or run: copilot  (env var is exported in this script's environment too)"
