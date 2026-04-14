# Troubleshooting Guide

## Subagents Getting Killed Mid-Run

**Symptom:** OpenClaw subagent shows `"outcome": { "status": "error", "error": "killed" }`

**Cause:** Corporate proxy (Zscaler) drops long-running HTTPS streams to Ollama cloud.

**Fix:**
```bash
# Disable Zscaler tray (no sudo)
scripts/disable-zscaler.sh --tray

# Disable system daemons (requires sudo in Terminal)
sudo launchctl unload /Library/LaunchDaemons/com.zscaler.service.plist
sudo launchctl unload /Library/LaunchDaemons/com.zscaler.tunnel.plist
```

**Permanent disable (survives reboot):**
```bash
sudo launchctl disable system/com.zscaler.service
sudo launchctl disable system/com.zscaler.tunnel
```

---

## MCP Servers Not Loading in Claude Code

**Symptom:** `/mcp` command in Claude Code shows no servers, or tools aren't available.

**Check:**
```bash
python3 -c "import json; d=json.load(open('~/.claude.json'.replace('~','$HOME'))); print(d.get('mcpServers',{}).keys())"
```

**Fix:**
```bash
scripts/setup-mcp.sh        # Adds servers (skips existing)
scripts/setup-mcp.sh --force  # Re-applies all servers from template
```

**Then restart Claude Code.** MCP servers are loaded at startup.

---

## OpenClaw Web Search Not Working

**Symptom:** `ollama_web_search` tool returns errors or isn't available.

**Check:**
```bash
python3 -c "
import json; c=json.load(open('$HOME/.openclaw/openclaw.json'))
print('web fetch:', c['tools']['web']['fetch']['enabled'])
print('web search:', c['tools']['web']['search']['enabled'])
print('ollama plugin:', c['plugins']['entries']['ollama']['enabled'])
"
```

**Fix:**
```bash
scripts/setup-openclaw.sh
```

**Then restart OpenClaw** (`ollama launch openclaw`).

---

## `ollama launch claude` Uses Wrong Model

**Symptom:** Claude Code launches but uses Anthropic API instead of Ollama.

**Fix:** Ensure the ollama integration is configured:
```bash
cat ~/.ollama/config.json
# Should show "claude" -> models array
```

If missing, restore from template:
```bash
cp configs/ollama-integrations.json ~/.ollama/config.json
# Edit model names as needed
```

---

## Codex "model_provider not recognized" Error

**Symptom:** `codex` fails with provider error when `model_provider="oss"`.

**Note:** `model_provider="oss"` only works as a CLI flag, NOT in `config.toml`.
The correct approach is `model_provider = "ollama-launch"` in config (what this repo sets).

**Fix:**
```bash
scripts/setup-codex.sh
```

If you need to pass `--oss` temporarily: `command codex --oss`

---

## npm/npx MCP Servers Fail (Corporate Network)

**Symptom:** MCP servers like `memory` or `context7` fail to start, npm errors.

**Cause:** Corporate CA certificate not trusted by Node.js.

**Fix 1:** Ensure the CA bundle is set:
```bash
# Check ~/.zshrc has:
export NODE_EXTRA_CA_CERTS=~/.mamba_ca_bundle.pem
```

**Fix 2:** The MCP server configs in `configs/claude-mcp-servers.json` already include
`NODE_EXTRA_CA_CERTS` in the env. Re-run `scripts/setup-mcp.sh` if needed.

**Fix 3:** For fully offline setups, pre-cache the npx packages:
```bash
npm install -g @modelcontextprotocol/server-memory
npm install -g @modelcontextprotocol/server-sequential-thinking
npm install -g @upstash/context7-mcp
npm install -g @playwright/mcp
```
Then update `configs/claude-mcp-servers.json` to use `node` instead of `npx`.

---

## Skills Not Loading for Claude Code

**Symptom:** `cat ~/.claude/skills-cache/combined-skills.txt` is empty or file missing.

**Fix:**
```bash
./safe-install.sh    # Re-runs ECC installation + rebuilds skills cache
```

---

## Shell Aliases Not Working

**Symptom:** `ollama`, `claude`, `openclaw` commands don't seem wrapped.

**Fix:**
```bash
source ~/.zshrc

# Verify aliases are set:
alias | grep -E "^(claude|openclaw|codex|ollama|pi)="
```

If not set:
```bash
./install.sh --only skills   # Reinstalls the shell block
```

---

## `ollama serve` / Ollama Server Not Starting

**Symptom:** All tools fail with connection refused on `localhost:11434`.

**Fix:**
```bash
open /Applications/Ollama.app
# or
ollama serve &
```

**Check:**
```bash
curl http://localhost:11434/api/status
ollama list
```

---

## Pi Subagents Failing

**Symptom:** Pi research tasks fail or pi-subagents not found.

**Check:**
```bash
cat ~/.pi/agent/settings.json
pi --version
```

**Fix:**
```bash
scripts/setup-pi.sh
# Then reinstall packages from within pi:
# /packages install pi-subagents
```

---

## Full Reset

If something is badly misconfigured:
```bash
# Restore from backup (backups created automatically by each setup script)
ls ~/.claude.json.bak_*          # Find latest backup
cp ~/.claude.json.bak_YYYYMMDD_HHMMSS ~/.claude.json

ls ~/.openclaw/openclaw.json.bak_*
cp ~/.openclaw/openclaw.json.bak_YYYYMMDD_HHMMSS ~/.openclaw/openclaw.json

# Then re-run setup
./install.sh
```
