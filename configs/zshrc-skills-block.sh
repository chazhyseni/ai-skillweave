
# =============================================================================
# Skills Layer — Everything Claude Code
# =============================================================================
# All harness commands get the ECC skills injected automatically.
# Injected by: ~/scripts/agent_harness_modifications/install.sh
# To remove:   ~/scripts/agent_harness_modifications/install.sh --uninstall
# =============================================================================

# Claude Code: inject skills via --append-system-prompt-file
_claude_with_skills() {
    local _skills_file="/tmp/claude-skills-$$.txt"
    cat ~/.claude/skills-cache/combined-skills.txt > "$_skills_file" 2>/dev/null
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
alias learn-sync='~/scripts/agent_harness_modifications/sync-learned-skills.sh'
alias learn-sync-dry='~/scripts/agent_harness_modifications/sync-learned-skills.sh --dry-run --verbose'

# Wrapper aliases
alias claude='_claude_with_skills'
alias openclaw='_openclaw_with_skills'
alias codex='_codex_with_skills'
alias ollama='_ollama_with_skills'
alias pi='_pi_with_skills'
# End Skills Layer
