# Ollama Agent Harness Modifications

One-command setup to configure all AI agent harnesses (`ollama launch claude`, `openclaw`, `pi`, `codex`) with proper MCP servers, skills, and network settings — reproducible across machines.

---

## Quick Start (New Machine)

```bash
# 1. Clone this repo
git clone <your-repo-url> ~/scripts/agent_harness_modifications
cd ~/scripts/agent_harness_modifications

# 2. Install everything
./install.sh

# 3. Reload shell
source ~/.zshrc

# 4. Launch any harness
ollama launch claude      # Claude Code + MCP tools
ollama launch openclaw    # OpenClaw + subagents + web
ollama launch pi          # Pi + subagents
ollama launch codex       # Codex via Ollama backend
```

---

## What This Repo Does

| Component | What it configures |
|-----------|-------------------|
| **Claude Code MCP** | Adds `memory`, `sequential-thinking`, `context7`, `playwright`, `google-docs-editor` to `~/.claude.json` |
| **OpenClaw** | Enables web tools + Ollama plugin in `~/.openclaw/openclaw.json` |
| **Pi** | Sets Ollama as provider + installs `pi-subagents` package |
| **Codex** | Configures `ollama-launch` provider in `~/.codex/config.toml` |
| **Shell wrappers** | Adds `_*_with_skills` functions + aliases in `~/.zshrc` |
| **ECC Skills** | Installs 1,789+ Everything Claude Code skills for all harnesses |
| **Zscaler** | Detects and disables proxy (prevents stream drops on cloud models) |

---

## Repository Structure

```
agent_harness_modifications/
├── install.sh                    ← Master installer (run this)
├── safe-install.sh               ← ECC skills installer
├── sync-learned-skills.sh        ← Sync learned skills across harnesses
├── extract-conversation-skills.py ← Extract patterns from conversation history
│
├── configs/                      ← Portable config templates
│   ├── claude-mcp-servers.json   ← MCP servers for Claude Code
│   ├── openclaw.json             ← OpenClaw config (web tools enabled)
│   ├── codex-config.toml         ← Codex ollama-launch provider config
│   ├── pi-settings.json          ← Pi agent settings
│   ├── ollama-integrations.json  ← Ollama integration→model mapping
│   └── zshrc-skills-block.sh     ← Shell skills layer block
│
├── scripts/                      ← Individual setup scripts
│   ├── setup-mcp.sh              ← Inject MCP into ~/.claude.json
│   ├── setup-openclaw.sh         ← Apply OpenClaw config
│   ├── setup-codex.sh            ← Apply Codex config
│   ├── setup-pi.sh               ← Apply Pi settings
│   ├── disable-zscaler.sh        ← Disable Zscaler proxy
│   └── verify.sh                 ← Health check all components
│
├── docs/
│   ├── AUDIT.md                  ← MCP/subagent audit (what was fixed + why)
│   └── TROUBLESHOOTING.md        ← Common issues and fixes
│
└── shared-learnings/
    └── learnings.md              ← Cross-harness learned patterns log
```

---

## Prerequisites

| Tool | Install |
|------|---------|
| [Ollama](https://ollama.com) | `brew install ollama` or download app |
| Python 3 | `brew install python3` |
| Node.js | `brew install node` (for npx-based MCP servers) |
| Claude Code | `npm install -g @anthropic-ai/claude-code` |
| OpenClaw | `ollama launch openclaw --config` |
| Pi | `ollama launch pi` (first run installs it) |
| Codex | `npm install -g @openai/codex` |

---

## Install Options

```bash
# Full setup (default model: qwen3.5:397b-cloud)
./install.sh

# Use a local model instead (faster, no cloud dependency)
./install.sh --model llama3.2:3b
./install.sh --model qwen2.5-coder:7b

# Configure only specific harnesses
./install.sh --only claude
./install.sh --only openclaw
./install.sh --only pi
./install.sh --only codex

# Skip ECC skills installation (faster, if skills already installed)
./install.sh --skip-skills

# Run health check
./install.sh --verify
# or: scripts/verify.sh

# Uninstall shell layer only (configs preserved)
./install.sh --uninstall
```

---

## MCP Servers (Claude Code)

These are automatically configured by `scripts/setup-mcp.sh`:

| Server | What it does |
|--------|-------------|
| `memory` | Persistent memory across Claude Code sessions |
| `sequential-thinking` | Chain-of-thought reasoning tool |
| `context7` | Live docs lookup for any library/framework |
| `playwright` | Browser automation from within Claude Code |
| `google-docs-editor` | Read/write Google Docs (local server, pre-built) |

### Adding API-Key-Gated Servers

1. Copy an entry from `configs/claude-mcp-servers.json` (`_api_key_servers_commented` section)
2. Move it to the `mcpServers` block
3. Fill in your API key
4. Run `scripts/setup-mcp.sh --force`

Or use the Claude Code CLI:
```bash
# GitHub
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=ghp_xxx \
  -- npx -y @modelcontextprotocol/server-github

# Exa web search
claude mcp add exa -e EXA_API_KEY=exa_xxx -- npx -y exa-mcp-server
```

---

## OpenClaw Subagents

OpenClaw's native subagent system works via `~/.openclaw/subagents/`. After setup:

- Web tools (`ollama_web_search`, `ollama_web_fetch`) are enabled via the Ollama plugin
- Gateway runs on `localhost:18789`
- Skills are loaded from `~/.openclaw/workspace/skills/` (ECC skills copied there)

---

## Skills Layer

Every harness command is wrapped to inject ECC skills:

```
ollama launch claude   →  _claude_with_skills()   →  injects via --append-system-prompt-file
ollama launch openclaw →  _openclaw_with_skills() →  loads from ~/.openclaw/workspace/skills/
ollama launch pi       →  _pi_with_skills()       →  loads from ~/.pi/agent/skills/
ollama launch codex    →  _codex_with_skills()    →  loads from ~/.codex/skills/
```

To sync newly-learned skills across all harnesses:
```bash
learn-sync          # Full sync
learn-sync-dry      # Preview only
```

---

## Zscaler / Corporate Proxy

If on a machine with Zscaler, the proxy **will drop long-running Ollama cloud streams**,
killing subagents mid-generation. This repo handles it automatically:

- `install.sh` auto-unloads the Zscaler tray (no sudo needed)
- System daemons require manual sudo (see post-setup message)
- All npx MCP servers have `NODE_EXTRA_CA_CERTS` configured for corporate CA bundles

After reboot, Zscaler may restart. Run:
```bash
scripts/disable-zscaler.sh
# Then in a Terminal (for sudo):
sudo launchctl unload /Library/LaunchDaemons/com.zscaler.service.plist
sudo launchctl unload /Library/LaunchDaemons/com.zscaler.tunnel.plist
```

---

## Cloud vs Local Models

All model names ending in `-cloud` or `:cloud` are Ollama cloud-hosted (no local GPU needed, but require internet):

| Model | Type | Notes |
|-------|------|-------|
| `qwen3.5:397b-cloud` | ☁️ Cloud | High quality, ~1-5 min responses |
| `qwen3.5:cloud` | ☁️ Cloud | Same endpoint as 397b-cloud |
| `llama3.2:3b` | 💻 Local | Fast, ~5-10 sec responses |
| `qwen2.5-coder:7b` | 💻 Local | Good for coding, ~30 sec responses |

For subagent tasks that don't need maximum quality, use a local model:
```bash
ollama pull llama3.2:3b
./install.sh --model llama3.2:3b
```

---

## See Also

- `docs/AUDIT.md` — Full audit of MCP and subagent issues found and fixed
- `docs/TROUBLESHOOTING.md` — Common problems and solutions
- `~/.claude-everything-claude-code/` — Full ECC skills repository
- `~/.claude-everything-claude-code/mcp-configs/mcp-servers.json` — Complete MCP server reference
