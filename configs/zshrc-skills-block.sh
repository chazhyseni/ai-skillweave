
# =============================================================================
# Skills Layer — Everything Claude Code
# =============================================================================
# All harness commands get the ECC skills injected automatically.
# Injected by: ai-skillweave/install.sh
# To remove:   ai-skillweave/safe-install.sh --uninstall
# =============================================================================

# Claude Code: inject personal learned skills as system prompt supplement.
# Uses lean-skills.txt (~personal skills only, ~1-2K tokens) NOT combined-skills.txt
# (~1.4M tokens which would exceed Claude's 200K context window and crash the session).
# The full 450+ skill library is already natively available via Claude Code's /skills
# command from ~/.claude/skills/ — no injection needed for those.
_claude_with_skills() {
    local _skills_file="/tmp/claude-skills-$$.txt"
    cat ~/.claude/skills-cache/lean-skills.txt > "$_skills_file" 2>/dev/null
    if [ -s "$_skills_file" ]; then
        (unset SKILLS_CONTENT CODEX_SYSTEM_PROMPT OPENCLAW_SYSTEM_PROMPT; command claude --append-system-prompt-file "$_skills_file" "$@")
    else
        (unset SKILLS_CONTENT CODEX_SYSTEM_PROMPT OPENCLAW_SYSTEM_PROMPT; command claude "$@")
    fi
    rm -f "$_skills_file"
}

# OpenClaw: loads SKILL.md files natively from ~/.openclaw/workspace/skills/
_openclaw_with_skills() {
    (unset SKILLS_CONTENT CODEX_SYSTEM_PROMPT OPENCLAW_SYSTEM_PROMPT; command openclaw "$@")
}

# Codex: loads skills natively from ~/.codex/skills/ (ECC skills symlinked there)
_codex_with_skills() {
    (unset SKILLS_CONTENT OPENCLAW_SYSTEM_PROMPT; command codex "$@")
}

# Ollama: pass-through with env cleanup (openclaw/codex/pi load skills natively)
_ollama_with_skills() {
    (unset SKILLS_CONTENT CODEX_SYSTEM_PROMPT OPENCLAW_SYSTEM_PROMPT OLLAMA_SYSTEM_FILE; command ollama "$@")
}

# Pi: loads skills natively from ~/.pi/agent/skills/
_pi_with_skills() {
    (unset SKILLS_CONTENT CODEX_SYSTEM_PROMPT OPENCLAW_SYSTEM_PROMPT; command pi "$@")
}

# Cross-harness skill learner
alias learn-sync='bash ~/.claude/scripts/sync-learned-skills.sh'
alias learn-sync-dry='bash ~/.claude/scripts/sync-learned-skills.sh --dry-run --verbose'
alias learn-stats='bash ~/.claude/scripts/sync-learned-skills.sh --stats'
alias learn-prune='bash ~/.claude/scripts/sync-learned-skills.sh --prune'

# Wrapper aliases
alias claude='_claude_with_skills'
alias openclaw='_openclaw_with_skills'
alias codex='_codex_with_skills'
alias ollama='_ollama_with_skills'
alias pi='_pi_with_skills'
# End Skills Layer
