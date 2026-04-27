# Troubleshooting

## "context limit reached" on every Claude Code session

**Cause:** An old install injected `combined-skills.txt` (~5.5MB ≈ 1.375M tokens) as a system prompt. Claude Sonnet 4.6/Opus 4.7 have a 200K token context window — 6.9× overflow.

**Fix:** Re-run the installer to replace the old wrapper with the lean-skills version:

```bash
./install.sh --only skills
source ~/.zshrc   # or ~/.bashrc
```

The new wrapper injects only `lean-skills.txt` (~1-2K tokens — your personal learned skills). The full 450+ skill library loads natively from `~/.claude/skills/` via Claude Code's built-in `/skills` feature.

---

## Ollama model "works" but Claude hits context limit

Ollama silently truncates prompts to its `num_ctx` limit — no error, skills silently dropped. Claude Code uses the Anthropic API directly, which returns an explicit `context_length_exceeded` error when the system prompt is too large. This is by design — the fix is to use `lean-skills.txt`.

---

## Skills not appearing in Copilot CLI

Copilot CLI natively discovers `SKILL.md` files from `~/.claude/skills/` at startup. If no skills appear:

1. Verify skills are installed: `ls ~/.claude/skills/ | wc -l` (should be 300+)
2. Re-run skills install: `./install.sh --only skills`
3. Restart Copilot

To disable a specific skill: add its name to `disabledSkills` in `~/.copilot/settings.json`.

To add extra skill directories: set `COPILOT_SKILLS_DIRS=/path/to/skills` in your shell rc.

---

## MCP server fails to start

```bash
# Check which MCP servers are configured
cat ~/.claude.json | python3 -m json.tool | grep -A5 mcpServers

# Re-apply MCP config
scripts/setup-mcp.sh --force

# Verify all servers
./install.sh --verify
```

---

## beads `bd` command not found

```bash
scripts/setup-beads.sh
# or manually:
uv tool install beads-mcp    # installs both bd and beads-mcp
```

---

## Proxy / Zscaler intercepting Ollama streams

```bash
scripts/disable-zscaler.sh         # disable proxy
scripts/disable-zscaler.sh --tray  # also kill tray agent
```

Add `NO_PROXY=localhost,127.0.0.1` to your shell rc to bypass proxy for local Ollama.

---

## Shell aliases not working after install

```bash
source ~/.zshrc    # macOS
source ~/.bashrc   # Linux/WSL

# Verify the wrapper is installed
grep "_claude_with_skills" ~/.zshrc || grep "_claude_with_skills" ~/.bashrc
```

---

## Re-running install.sh after a previous install

Safe to re-run at any time. The installer:

- Removes the old shell wrapper block before writing the new one (idempotent)
- Skips existing git clones (use `--force` to re-clone)
- Merges MCP servers (doesn't overwrite existing entries unless `--force` is passed to setup-mcp.sh)
- Rebuilds the skills cache from the current state of `~/.claude/skills/`
