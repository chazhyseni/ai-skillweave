# Troubleshooting

## "context limit reached" on every Claude Code session

**Cause:** An old install injected `combined-skills.txt` (~4.9 MB ≈ 1.23M tokens) as a system prompt. Claude Sonnet 4.6/Opus 4.7 have a 200K token context window — 6.1× overflow.

**Fix:** Re-run the installer to replace the old wrapper with the lean-skills version:

```bash
./install.sh --only skills
source ~/.zshrc   # or ~/.bashrc
```

The new wrapper injects only `lean-skills.txt` (currently 205 bytes ≈ 51 tokens — your personal learned skills). The full skill library loads natively from `~/.claude/skills/` via Claude Code's built-in `/skills` feature.

---

## Ollama model "works" but Claude hits context limit

Ollama silently truncates prompts to its `num_ctx` limit — no error, skills silently dropped. Claude Code uses the Anthropic API directly, which returns an explicit `context_length_exceeded` error when the system prompt is too large. This is by design — the fix is to use `lean-skills.txt`.

---

## Skills not appearing in Copilot CLI

Copilot CLI bridges the cross-harness skill pool via `scripts/setup-copilot-skills.sh`. The bridge installs:
  - A symlink `~/.copilot/config/skills -> ~/.claude/skills` (native Copilot path)
  - The env-var `COPILOT_SKILLS_DIRS=~/.claude/skills:~/.pi/agent/skills` in your shell rc
  - An updated `_copilot_with_skills()` wrapper that sets the env-var inline as a fallback

If no skills appear in Copilot:

1. **Check the bridge is installed:** `scripts/setup-copilot-skills.sh --check` — all three checks should pass.
2. **Verify skills are installed:** `ls ~/.claude/skills/ | wc -l` (should be 1,500+; this box has 1,702 after full install).
3. **Re-run the skills install:** `./install.sh --only skills` then re-run `scripts/setup-copilot-skills.sh`.
4. **Reload your shell** so the env-var export takes effect: `source ~/.bashrc` (or `~/.zshrc`).
5. **Restart Copilot** so it re-discovers skills on launch.

To disable a specific skill: add its name to `disabledSkills` in `~/.copilot/settings.json`.

To add extra skill directories beyond what the bridge provides: set `COPILOT_SKILLS_DIRS=/path/to/skills` in your shell rc (the bridge will use this in place of the default if set).

To remove the bridge entirely: `scripts/setup-copilot-skills.sh --unlink`.

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
