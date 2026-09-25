# Skills Layer — ai-skillweave
# Native skills are discovered by each harness; do not override user command aliases.
# Learning commands use the installed runtime and its isolated Python environment.
alias learn-sync='bash "$HOME/.claude/scripts/sync-learned-skills.sh"'
alias learn-sync-dry='bash "$HOME/.claude/scripts/sync-learned-skills.sh" --dry-run'
alias learn-stats='bash "$HOME/.claude/scripts/sync-learned-skills.sh" --stats'
alias learn-prune='bash "$HOME/.claude/scripts/sync-learned-skills.sh" --prune'
alias skills-update='bash "$HOME/.claude/scripts/scripts/update-ecc.sh"'
# End Skills Layer
