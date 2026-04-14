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
| **Codex** | Configures `ollama-launch` provider + `danger-full-access` sandbox in `~/.codex/config.toml` |
| **Ollama integrations** | Sets per-harness model mapping in `~/.ollama/config.json` (minimax for claude/cline/codex, qwen for openclaw/pi) |
| **Shell wrappers** | Adds `_*_with_skills` functions + aliases in `~/.zshrc` |
| **ECC Skills** | Installs ECC + Anthropic official + 469 Codex skills (~775 files → 1.16MB cache) |

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

## Before You Begin — First-Time Setup

Run these steps **once** on a new machine before cloning this repo.

### 1. Install Ollama

```bash
# macOS — download the app (recommended) or use brew:
brew install ollama
# or: download from https://ollama.com and open /Applications/Ollama.app
```

After installing, Ollama runs as a menubar app. Make sure it's running before launching any harness.

### 2. Pull a model (or use cloud models)

```bash
# Cloud model — no download needed, streams from Ollama's servers:
ollama pull qwen3.5:397b-cloud    # or minimax-m2.7:cloud

# Local model — runs on your machine (~2GB download):
ollama pull llama3.2:3b           # fast, good for subagents
```

### 3. Install Node.js (for MCP servers)

```bash
brew install node
# Verify: node --version  (needs v18+)
```

### 4. Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code

# Authenticate (requires Claude Pro/Max/Team account):
claude auth login
# → opens browser, log in with your Anthropic account

# Verify it works:
claude --version
```

### 5. Install OpenClaw, Pi, Codex (optional — install only what you use)

```bash
# OpenClaw — first run downloads and configures it:
ollama launch openclaw --config
# → follow the onboarding wizard, then quit

# Pi — first run installs it:
ollama launch pi
# → let it initialize, then Ctrl+C once it's ready

# Codex CLI:
npm install -g @openai/codex
```

> **Note:** OpenClaw, Pi, and Codex are optional. `install.sh` will skip harnesses that aren't installed and show a warning.

### 6. Install Python 3 (usually pre-installed on macOS)

```bash
# Check: python3 --version  (needs 3.8+)
# If missing: brew install python3
```

---

## Prerequisites Summary

| Tool | Required? | One-line install |
|------|-----------|-----------------|
| [Ollama](https://ollama.com) | ✅ Required | Download app or `brew install ollama` |
| Python 3 | ✅ Required | Pre-installed on macOS, or `brew install python3` |
| Node.js | ✅ Required | `brew install node` |
| Claude Code | ✅ Required | `npm install -g @anthropic-ai/claude-code` + `claude auth login` |
| OpenClaw | Optional | `ollama launch openclaw --config` (first run installs) |
| Pi | Optional | `ollama launch pi` (first run installs) |
| Codex | Optional | `npm install -g @openai/codex` |

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
| OpenAI Codex | **469** (all loaded) | In `openai-codex/skills/`; previously capped at 100, now uncapped |
| Community curated | 0 (catalog only) | Web-based skill index, no downloadable files |
| Personal learned | varies | Your own patterns extracted from sessions |
| **Claude Code cache total** | **~775 files → 1.16MB** | Combined into `combined-skills.txt` |

### What ai-skillweave Adds

ECC was originally built for Claude Code. **ai-skillweave extends it across every `ollama launch` harness.**

All harnesses get the same **240 structured skill entry points** (183 ECC + 17 Anthropic official + 44 Codex curated). The apparent "775 vs 244" discrepancy is **not a gap** — it's a difference in how content is counted:

| What's counted | Claude Code | OpenClaw / Pi / Codex |
|----------------|-------------|----------------------|
| **SKILL.md entry points** (the actual skills) | **240** | **240–289** |
| Raw `.md` files in injection | **~775** | N/A |

The 775 `.md` files include supporting content within each skill directory (e.g., theme variants, reference docs, spec files) that get text-concatenated into Claude's system prompt. OpenClaw/Pi/Codex load skills via the `SKILL.md` entry-point format, which points to the same skill logic.

| Harness | Skill dirs | How they load |
|---------|-----------|--------------|
| `ollama launch claude` | 240 structured skills + ~535 supporting .md files | All text injected via `--append-system-prompt-file` |
| `ollama launch openclaw` | **244** (240 unified + 3 personal learned + extras) | Real SKILL.md copies, YAML-sanitized |
| `ollama launch pi` | **244** (same) | Symlinks to skill source dirs |
| `ollama launch codex` | **~289** (244 + 46 native Codex) | Symlinks + YAML-sanitized copies |

> **YAML sanitization:** Skills with block-scalar descriptions or extra fields (`homepage`, `license`, `version`, `metadata`) are automatically sanitized on-the-fly without modifying source files.

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

## Token Efficiency — Skills Injection + Prompt Caching

All 775 skills (~1.16MB / ~289K tokens) are injected into every `claude` session via `--append-system-prompt-file`. This sounds expensive, but Claude Code's **prompt caching** makes it economical:

### How caching works

| Event | Cost at Opus pricing |
|-------|---------------------|
| Session 1 (cache miss) | ~$4.35 (289K × $15/MTok) |
| Session 2+ same day (cache hit) | ~$0.43 (289K × $1.50/MTok cache read) |
| Each conversation turn | Only new tokens in the exchange |

**5 sessions/day with caching: $4.35 + 4 × $0.43 = $6.07**  
Without caching it would be $4.35 × 5 = $21.75. With caching: **72% cheaper.**

### What's already enabled

`setup-mcp.sh` sets `tengu_system_prompt_global_cache: true` in `~/.claude.json`. This persists the cache **across sessions** (not just within one session), so the system prompt (skills injection) is reused from cache as long as the file content doesn't change.

Running `./install.sh` on a new machine configures this automatically.

### Why full injection beats selective injection

Selective/on-demand loading requires the user to know which skills to activate. Full injection means Claude automatically applies relevant skills (TDD when writing tests, security review when touching auth, etc.) **without any explicit invocation** — which is the whole point.

### `lean-skills.txt` — optional fallback

`~/.claude/skills-cache/lean-skills.txt` contains only your 3 personal learned skills (~6K tokens) as a fallback for situations where you want minimal injection. Switch via `.zshrc`:
```bash
# In _claude_with_skills function, change:
cat ~/.claude/skills-cache/combined-skills.txt   # ← full 775 skills (default)
# to:
cat ~/.claude/skills-cache/lean-skills.txt        # ← personal skills only
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
