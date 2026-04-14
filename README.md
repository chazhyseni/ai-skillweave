# ai-skillweave

> Weaving skills, MCP, and configs across every AI agent harness — `ollama launch claude`, `openclaw`, `pi`, `codex` — on any machine.

One-command setup for all your Ollama agent harnesses: proper MCP servers, web tools, and harness-specific configs, all portable and reproducible.

---

## Built on Everything Claude Code (ECC)

> **The skills powering this repo come from [Everything Claude Code](https://github.com/affaan-m/everything-claude-code)** — a community-maintained library of production-ready AI agent skills covering every domain of software development.

`ai-skillweave`'s core contribution is **cross-harness delivery**: ECC was originally designed for Claude Code only. This repo extends it so the same skill library loads natively into every `ollama launch` agent — OpenClaw, Pi, Codex, and Claude Code — each in the format that harness expects.

If you find the skills useful, go star ⭐ [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code).

---

## Quick Start (New Machine)

```bash
# 1. Clone this repo
git clone https://github.com/chazhyseni/ai-skillweave ~/scripts/agent_harness_modifications
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
| **Claude Code MCP** | Adds 6 servers to `~/.claude.json`: memory, sequential-thinking, context7, playwright, google-docs-editor, token-optimizer |
| **OpenClaw** | Enables web tools + Ollama plugin in `~/.openclaw/openclaw.json` |
| **Pi** | Sets Ollama as provider + installs `pi-subagents` package |
| **Codex** | Configures `ollama-launch` provider in `~/.codex/config.toml` |
| **Shell wrappers** | Adds `_*_with_skills` functions + aliases in `~/.zshrc` |
| **ECC Skills** | Installs ECC + Anthropic official + Codex skills across all harnesses |

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
│   ├── setup-ollama-config.sh    ← Apply Ollama integration→model mapping
│   ├── update-ecc.sh             ← Pull latest ECC + rebuild cache + re-sync harnesses
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

### Automatically applied by `./install.sh` (no API keys needed)

`scripts/setup-mcp.sh` reads `configs/claude-mcp-servers.json` and merges these into `~/.claude.json`:

| Server | What it does |
|--------|-------------|
| `memory` | Persistent memory across Claude Code sessions |
| `sequential-thinking` | Chain-of-thought reasoning tool |
| `context7` | Live docs lookup for any library/framework |
| `playwright` | Browser automation from within Claude Code |
| `google-docs-editor` | Read/write Google Docs (local server, pre-built) |
| `token-optimizer` | 95%+ context reduction via deduplication — saves Opus tokens |

**No tokens or API keys needed for any of the above.** `install.sh` applies them automatically on a new machine.

### Manually added (require API keys)

The `_api_key_servers_commented` block in `configs/claude-mcp-servers.json` contains templates that are **never auto-applied** — you fill them in and add them yourself:

```bash
# GitHub (needs a PAT from github.com/settings/tokens)
claude mcp add github \
  -e GITHUB_PERSONAL_ACCESS_TOKEN=ghp_YOUR_TOKEN \
  --scope user \
  -- npx -y @modelcontextprotocol/server-github

# Exa web search (needs key from exa.ai)
claude mcp add exa \
  -e EXA_API_KEY=exa_xxx \
  --scope user \
  -- npx -y exa-mcp-server
```

To add a server from the template: copy it from `_api_key_servers_commented` → move it to `mcpServers` → fill in the real key → run `scripts/setup-mcp.sh --force`.

---

## OpenClaw Subagents

OpenClaw's native subagent system works via `~/.openclaw/subagents/`. After setup:

- Web tools (`ollama_web_search`, `ollama_web_fetch`) are enabled via the Ollama plugin
- Gateway runs on `localhost:18789`
- Skills are loaded from `~/.openclaw/workspace/skills/` (ECC skills copied there)

---

## ECC Skills — Everything Claude Code

This repo is built on top of **[Everything Claude Code (ECC)](https://github.com/affaan-m/everything-claude-code)** — a community-maintained library of production-ready skills covering every domain of software development: testing, architecture, security, cloud deployment, language-specific patterns, and more.

### What ECC Is

ECC skills are structured Markdown prompts (`.md` files) that tell AI agents *how to think* about specific tasks. Each skill covers: when to activate, how to approach the problem, examples, and pitfalls. They're harness-agnostic by design.

### Skill Counts (verified)

| Source | Skills | Notes |
|--------|--------|-------|
| ECC core | 183 SKILL.md dirs | 185 total dirs, 2 are local-only (learned + project-guidelines-example) |
| Anthropic official | 64 | In `anthropic-official/skills/` subdir (excludes README/docs) |
| OpenAI Codex | 470 available, 100 loaded | In `openai-codex/skills/`; capped to preserve context window |
| Community curated | 0 (catalog only) | Web-based skill index, no downloadable files |
| Personal learned | varies | Your own patterns extracted from sessions |
| **Claude Code cache total** | **~407 files → 1.1MB** | Combined into `combined-skills.txt` |

### What ai-skillweave Adds

ECC was originally built for Claude Code. **ai-skillweave extends it across every `ollama launch` harness:**

| Harness | Skills | How they load |
|---------|--------|--------------|
| `ollama launch claude` | ~407 (all sources) | Injected via `--append-system-prompt-file` at startup |
| `ollama launch openclaw` | 187 (183 ECC + 3 learned + extras) | Real `.md` file copies, YAML-sanitized for compatibility |
| `ollama launch pi` | 187 (183 ECC + 3 learned + extras) | Symlinks to ECC skill dirs |
| `ollama launch codex` | 230 (183 ECC + 46 native) | Symlinks + YAML-sanitized copies; 46 are native Codex skills |

> **YAML sanitization:** ECC skills with block-scalar descriptions or extra metadata fields (`homepage`, `license`, `version`) are automatically sanitized on-the-fly for OpenClaw and Codex compatibility without modifying the source files.

### Cross-Harness Skill Sync

When you learn something useful in one session, sync it everywhere:
```bash
learn-sync          # Extract patterns + sync to all harnesses
learn-sync-dry      # Preview what would sync
```

Learned skills live in `~/.claude/skills/learned/` and are automatically propagated to all harness-native skill directories.

### Installing ECC

```bash
./safe-install.sh                  # ECC only
./safe-install.sh --with-curated   # ECC + Anthropic official + community skills
```

### Keeping ECC Up to Date

When ECC adds new skills upstream, pull and rebuild without a full re-install:

```bash
scripts/update-ecc.sh           # Pull latest + rebuild cache + re-sync all harnesses
scripts/update-ecc.sh --check   # Just check if updates are available
scripts/update-ecc.sh --force   # Force cache rebuild even if already up to date
```

---

## Cloud vs Local Models

All model names ending in `-cloud` or `:cloud` are Ollama cloud-hosted (no local GPU needed, but require internet):

| Model | Type | Context | Best for |
|-------|------|---------|---------|
| `minimax-m2.7:cloud` | ☁️ Cloud | 1M tokens | Long context, multimodal, Claude Code / Cline |
| `qwen3.5:397b-cloud` | ☁️ Cloud | 256K | Reasoning, complex tasks, OpenClaw / Pi / Codex |
| `qwen3.5:cloud` | ☁️ Cloud | 256K | Same endpoint as 397b-cloud |
| `qwen3.5-claude:latest` | ☁️ Cloud | 256K | Claude-optimized fine-tune |
| `llama3.2:3b` | 💻 Local | 128K | Fast, ~5-10 sec, good for subagents |
| `qwen2.5-coder:7b` | 💻 Local | 128K | Coding tasks, offline use |

```bash
# Configure for Claude Code (large context tasks):
./install.sh --model minimax-m2.7:cloud

# Configure for OpenClaw / Pi / Codex (complex reasoning):
./install.sh --model qwen3.5:397b-cloud

# Add a local fallback model (no internet needed):
ollama pull llama3.2:3b
./install.sh --model llama3.2:3b
```

---

## See Also

- `docs/AUDIT.md` — Full audit of MCP and subagent issues found and fixed
- `docs/TROUBLESHOOTING.md` — Common problems and solutions
- `~/.claude-everything-claude-code/` — Full ECC skills repository
- `~/.claude-everything-claude-code/mcp-configs/mcp-servers.json` — Complete MCP server reference
