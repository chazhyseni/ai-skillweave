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
| **Claude Code MCP** | Adds 7 servers to `~/.claude.json`: memory, sequential-thinking, context7, playwright, google-docs-editor, token-optimizer, codesight |
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
│   ├── claude-mcp-servers.json   ← MCP servers for Claude Code CLI
│   ├── claude-desktop-mcp-servers.json  ← MCP servers for Claude Desktop GUI
│   ├── claude-desktop-project-instructions.md ← Curated skills for Desktop Project (generated)
│   ├── openclaw.json             ← OpenClaw config (web tools enabled)
│   ├── codex-config.toml         ← Codex ollama-launch provider config
│   ├── pi-settings.json          ← Pi agent settings
│   ├── ollama-integrations.json  ← Ollama integration→model mapping
│   └── zshrc-skills-block.sh     ← Shell skills layer block
│
├── scripts/                      ← Individual setup scripts
│   ├── setup-mcp.sh              ← Inject MCP into ~/.claude.json (CLI)
│   ├── setup-claude-desktop.sh   ← Standalone: MCP + skills for Claude Desktop GUI
│   ├── build-desktop-skills.sh   ← Generate curated skills file (essential/standard/full)
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
| `codesight` | Maps codebase routes, schema, components, dependencies — AI context for any project |

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

ECC skills are structured Markdown prompts (`.md` files) that tell AI agents *how to think* about specific tasks — when to activate, how to approach the problem, examples, and pitfalls.

### Skill Sources

| Source | Skills | Notes |
|--------|--------|-------|
| ECC core | 183 SKILL.md dirs | From `affaan-m/everything-claude-code` |
| Anthropic official | 17 SKILL.md dirs (64 total .md) | From Anthropic's official skills library |
| OpenAI Codex curated | 44 SKILL.md dirs (469 total .md) | From OpenAI's Codex skills collection |
| Personal learned | varies | Your own patterns extracted from sessions |

### What Each Harness Gets

| Harness | Skills | How they load |
|---------|--------|--------------|
| `ollama launch claude` | **~775 .md files → 1.16MB** | Full content injected via `--append-system-prompt-file` |
| `ollama launch openclaw` | **244 skill dirs** | Real SKILL.md copies, YAML-sanitized for compatibility |
| `ollama launch pi` | **244 skill dirs** | Symlinks to all skill source dirs |
| `ollama launch codex` | **~289 skill dirs** | Symlinks + YAML-sanitized copies + 46 native Codex skills |

Claude Code's 775 is the full text content of all skill files concatenated (including theme variants, reference docs, supporting files). Other harnesses use SKILL.md entry points — the structured skill definitions that trigger on the right tasks.

> **YAML sanitization:** Skills with block-scalar descriptions or extra metadata fields are automatically sanitized on-the-fly without modifying source files.

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

## Codebase Context — Codesight Integration

> **Powered by [codesight](https://github.com/Houseofmvps/codesight)** — *See your codebase clearly.* Universal AI context generator that maps routes, schema, components, dependencies, and more for Claude Code, Cursor, Copilot, Codex, and any AI coding tool.

### What codesight does

When Claude Code is working inside any repo, `codesight --mcp` provides a real-time context map so Claude understands *where things live* without manually exploring files. It generates:

- Route maps, schema, components, library dependencies
- `CLAUDE.md` — auto-generated project context for Claude Code
- `.cursorrules` — Cursor IDE rules
- `codex.md` / `AGENTS.md` — config for Codex and agentic tools
- `.codesight/CODESIGHT.md` — full AI context map (~200 tokens vs ~1,100 tokens of manual exploration)

### How it's integrated

`codesight` runs as an MCP server — one of the 7 servers applied automatically by `./install.sh`:

```bash
# Claude Code queries this server for codebase context automatically
npx -y codesight --mcp
```

### Using codesight in your own repos

```bash
# In any project root:
npx codesight --init           # Generate CLAUDE.md + .cursorrules + codex.md + AGENTS.md
npx codesight                  # Scan and update .codesight/CODESIGHT.md
npx codesight --wiki           # Generate wiki knowledge base
npx codesight --open           # Generate interactive HTML report + open in browser
npx codesight --max-tokens 50000  # Trim to fit token budget
```

When you run `npx codesight --init` in your own project, it generates `CLAUDE.md`, `.cursorrules`, `codex.md`, and `AGENTS.md` — commit those to your repo so Claude Code always has project context. The `.codesight/` scan directory is gitignored since it rebuilds every time you run a scan.


---

## Claude Desktop App (GUI) — Separate Setup

> **This is independent from `install.sh`** — the CLI and Desktop app have separate config files and separate setup scripts.

The Claude Desktop app (GUI) uses a different config path than Claude Code CLI. This repo includes a standalone setup script that adds MCP servers and builds curated skills for the Desktop app.

### Platform support

| Platform | Config path | Status |
|----------|------------|--------|
| **macOS** | `~/Library/Application Support/Claude/claude_desktop_config.json` | Tested |
| **Linux** | `~/.config/Claude/claude_desktop_config.json` | Supported (untested) |
| **Windows** | `%APPDATA%\Claude\claude_desktop_config.json` | Supported via Git Bash/WSL (untested) |

### Quick setup

```bash
# Full setup: MCP servers + curated skills file
./scripts/setup-claude-desktop.sh

# MCP servers only (zero token cost — servers idle until invoked)
./scripts/setup-claude-desktop.sh --mcp-only

# Build skills file only (for pasting into a Desktop Project)
./scripts/setup-claude-desktop.sh --skills-only

# Choose skill tier (default: full)
./scripts/setup-claude-desktop.sh --tier essential   # Personal learned skills only
./scripts/setup-claude-desktop.sh --tier standard    # Agents + top commands + personal
./scripts/setup-claude-desktop.sh --tier full        # All universal skills + personal
```

### What gets configured

**MCP servers** (7 from template + any API-key servers found in your CLI config — zero token cost until invoked):

| Server | Purpose |
|--------|---------|
| `codesight` | Codebase summaries, routes, schema, hot files |
| `context7` | Live library/framework docs |
| `memory` | Persistent memory across sessions |
| `sequential-thinking` | Chain-of-thought reasoning |
| `token-optimizer` | 95%+ context reduction via deduplication |
| `playwright` | Browser automation |
| `google-docs-editor` | Read/write Google Docs |
| `github` | GitHub API (copied from CLI config if configured) |
| `exa-web-search` | Neural web search (copied from CLI config if configured) |

**Curated skills** — built into `configs/claude-desktop-project-instructions.md`:

| Tier | Skills | Size | Tokens | What's included |
|------|--------|------|--------|-----------------|
| `essential` | varies | varies | varies | Personal learned skills only (from `~/.claude/skills/learned/`) |
| `standard` | 50 + personal | ~220KB+ | ~55K+ | + 27 universal agents + 23 top commands |
| `full` | 88 + personal | ~360KB+ | ~90K+ | + 27 universal agents + ALL ~61 universal commands |

### How skills get installed

`setup-claude-desktop.sh` writes individual SKILL.md files directly into the Desktop app's local skills directory:

```text
~/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/{session}/{org}/skills/
```

Skills appear in the Desktop app's **Skills** panel (Customize → Skills) automatically after restart.

1. Run `./scripts/setup-claude-desktop.sh` — configures MCP servers + installs skills
2. Restart Claude Desktop app
3. Skills appear in the Skills panel — no manual paste needed

To update skills later (e.g. after `update-ecc.sh`), re-run the setup script and restart Desktop.

### Token economics (Desktop)

| Component | Token cost |
|-----------|-----------|
| MCP servers | Zero until invoked |
| Skills (full tier) | ~90K+ tokens on first message, cached after that |
| Skills (standard tier) | ~55K+ tokens on first message, cached after that |

Skills are injected as Project instructions (system prompt) and cached by Claude after the first turn — similar to prompt caching in Claude Code CLI.

### CLI vs Desktop comparison

| Feature | Claude Code CLI | Claude Desktop GUI |
|---------|----------------|-------------------|
| Setup script | `install.sh` | `scripts/setup-claude-desktop.sh` |
| Config file | `~/.claude.json` | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| MCP servers | 7 auto + manual API-key servers | 7 auto + API-key servers copied from CLI |
| Skills injection | ~775 files via `--append-system-prompt-file` | 88 + personal via Project instructions |
| Prompt caching | `tengu_system_prompt_global_cache: true` | Built-in Project caching |
| Shell wrappers | `_claude_with_skills` in `.zshrc` | N/A (GUI app) |

---

## See Also

- `docs/TROUBLESHOOTING.md` — Common problems and solutions
- `~/.claude-everything-claude-code/` — Full ECC skills repository
- `~/.claude-everything-claude-code/mcp-configs/mcp-servers.json` — Complete MCP server reference
