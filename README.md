# ai-skillweave

> Weaving skills, MCP, and configs across every AI agent harness — `ollama launch claude`, `openclaw`, `pi`, `codex` — on any machine.

One-command setup for all your Ollama agent harnesses: proper MCP servers, web tools, and harness-specific configs, all portable and reproducible.

---

## Built on Everything Claude Code (ECC)

> **The skills powering this repo come from [Everything Claude Code](https://github.com/affaan-m/everything-claude-code)** — a community-maintained library of production-ready AI agent skills covering every domain of software development.

`ai-skillweave`'s core contribution is **cross-harness delivery**: ECC was originally designed for Claude Code only. This repo extends it so the same skill library loads natively into every `ollama launch` agent — OpenClaw, Pi, Codex, and Claude Code — each in the format that harness expects.

If you find the skills useful, go star ⭐ [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code).

---

## Scientific Agent Skills — K-Dense

> **134 scientific and research skills from [K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills)** — covering bioinformatics, cheminformatics, drug discovery, clinical research, proteomics, medical imaging, ML/AI, materials science, physics, and 100+ scientific databases.

These skills follow the open [Agent Skills](https://agentskills.io/) standard and work with Claude Code, Cursor, Codex, and Gemini CLI. `ai-skillweave` extends them to all supported harnesses, just like ECC skills.

To install:

```bash
./safe-install.sh --with-science                    # ECC + K-Dense scientific skills
./safe-install.sh --with-curated --with-science     # Full install: ECC + curated + scientific
```

If you find these scientific skills useful, go star ⭐ [K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills).

---

## Quick Start (New Machine)

```bash
# 1. Clone this repo
git clone https://github.com/chazhyseni/ai-skillweave ~/scripts/agent_harness_modifications
cd ~/scripts/agent_harness_modifications

# 2. Install everything (auto-detects macOS/Linux/WSL)
./install.sh

# 3. Reload shell (install.sh tells you which file)
source ~/.bashrc   # Linux/WSL
source ~/.zshrc    # macOS

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
| **Shell wrappers** | Adds `_*_with_skills` functions + aliases in `~/.bashrc` and/or `~/.zshrc` |
| **Claude Code skills** | Copies ECC SKILL.md files to `~/.claude/skills/` — visible via `/skills`, works with any launch method |
| **ECC Skills cache** | Combined skills cache at `~/.claude/skills-cache/combined-skills.txt` for system prompt injection |

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
│   ├── global-claude-md.md       ← Global CLAUDE.md template (MCP rules + conciseness)
│   ├── openclaw.json             ← OpenClaw config (web tools enabled)
│   ├── codex-config.toml         ← Codex ollama-launch provider config
│   ├── pi-settings.json          ← Pi agent settings
│   ├── ollama-integrations.json  ← Ollama integration→model mapping
│   └── zshrc-skills-block.sh     ← Shell skills layer block
│
├── scripts/                      ← Individual setup scripts
│   ├── setup-mcp.sh              ← Inject MCP into ~/.claude.json (CLI)
│   ├── setup-claude-md.sh        ← Install global CLAUDE.md (MCP rules + conciseness)
│   ├── setup-hooks.sh            ← Install PreToolUse hook (codesight-redirect)
│   ├── setup-claude-desktop.sh   ← Standalone: MCP + skills for Claude Desktop GUI
│   ├── build-desktop-skills.sh   ← Package .skill files for Desktop upload
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

## Platform Support

| Platform | Status | Shell | Notes |
|----------|--------|-------|-------|
| **macOS** | ✅ Tested | zsh (default) | Homebrew for dependencies |
| **Linux** | ✅ Tested | bash (default) | apt/dnf/pacman auto-detected |
| **Windows (WSL)** | ✅ Supported | bash | Run inside WSL — native Windows is not supported |
| **Windows (native)** | ⚠️ Limited | — | Use WSL instead; installer warns if run from Git Bash/MSYS2 |

`install.sh` auto-detects the platform and user shell, installs skills into the correct RC file (`~/.bashrc` or `~/.zshrc`), and shows platform-appropriate messages.

---

## Before You Begin — First-Time Setup

Run these steps **once** on a new machine before cloning this repo.

### 1. Install Ollama

```bash
# macOS:
brew install ollama
# or download from https://ollama.com

# Linux (Debian/Ubuntu):
curl -fsSL https://ollama.com/install.sh | sh

# Start the server:
ollama serve          # Linux (or use systemd)
# macOS: open /Applications/Ollama.app (runs as menubar app)
```

### 2. Pull a model (or use cloud models)

```bash
# Cloud model — no download needed, streams from Ollama's servers:
ollama pull qwen3.5:397b-cloud    # or minimax-m2.7:cloud

# Local model — runs on your machine (~2GB download):
ollama pull llama3.2:3b           # fast, good for subagents
```

### 3. Install Node.js (for MCP servers)

```bash
# macOS:
brew install node

# Linux (Debian/Ubuntu):
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Or use nvm (any platform):
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
nvm install --lts

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

> **Note:** OpenClaw, Pi, and Codex are optional. `install.sh` will skip harnesses that aren't installed and show a warning. Ollama is also optional — the installer warns but continues without it.

### 6. Install Python 3

```bash
# Check if already installed:
python3 --version  # needs 3.8+

# macOS:
brew install python3

# Linux (Debian/Ubuntu):
sudo apt-get install python3

# Linux (Fedora/RHEL):
sudo dnf install python3
```

---

## Prerequisites Summary

| Tool | Required? | macOS | Linux |
|------|-----------|-------|-------|
| [Ollama](https://ollama.com) | Optional (warn) | `brew install ollama` | `curl -fsSL https://ollama.com/install.sh \| sh` |
| Python 3 | ✅ Required | `brew install python3` | `apt install python3` or `dnf install python3` |
| Node.js | ✅ Required | `brew install node` | `apt install nodejs` or use nvm |
| Claude Code | ✅ Required | `npm install -g @anthropic-ai/claude-code` | Same |
| OpenClaw | Optional | `ollama launch openclaw --config` | Same |
| Pi | Optional | `ollama launch pi` | Same |
| Codex | Optional | `npm install -g @openai/codex` | Same |

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
| K-Dense scientific | 134 SKILL.md dirs | From `K-Dense-AI/scientific-agent-skills` |
| Anthropic official | 17 SKILL.md dirs (64 total .md) | From Anthropic's official skills library |
| OpenAI Codex curated | 44 SKILL.md dirs (469 total .md) | From OpenAI's Codex skills collection |
| Personal learned | varies | Your own patterns extracted from sessions |

### What Each Harness Gets

| Harness | Skills | How they load |
|---------|--------|--------------|
| `claude` / `ollama launch claude` | **317 native** + ~22K line cache | SKILL.md → `~/.claude/skills/` (native `/skills`) + full cache via `--append-system-prompt-file` |
| `ollama launch openclaw` | **317 skill dirs** | Real SKILL.md copies in `~/.openclaw/workspace/skills/`, YAML-sanitized |
| `ollama launch pi` | **317 skill dirs** | Symlinks in `~/.pi/agent/skills/` |
| `ollama launch codex` | **317 + 5 built-in** | YAML-sanitized copies in `~/.codex/skills/` + Codex system skills |

Native `~/.claude/skills/` installation means skills are visible via Claude Code's `/skills` command and load **regardless of launch method** (direct CLI, `ollama launch`, VSCode extension).

> **YAML sanitization:** Skills with block-scalar descriptions, extra metadata fields (author, version, tags), or nested YAML mappings are automatically sanitized without modifying source files.

### Cross-Harness Skill Sync

When you learn something useful in one session, sync it everywhere:
```bash
learn-sync          # Extract patterns + sync to all harnesses
learn-sync-dry      # Preview what would sync
```

Learned skills live in `~/.claude/skills/learned/` and are automatically propagated to all harness-native skill directories.

### Installing ECC

```bash
./safe-install.sh                                    # ECC only
./safe-install.sh --with-curated                     # ECC + Anthropic official + community skills
./safe-install.sh --with-science                     # ECC + K-Dense scientific skills (134 skills)
./safe-install.sh --with-curated --with-science      # Full install: all skill sources
```

### Keeping ECC Up to Date

When ECC adds new skills upstream, pull and rebuild without a full re-install:

```bash
scripts/update-ecc.sh           # Pull latest ECC + rebuild cache + re-sync all harnesses
scripts/update-ecc.sh --check   # Just check if updates are available
scripts/update-ecc.sh --force   # Force cache rebuild even if already up to date
```

To update K-Dense scientific skills, re-run with `--with-science`:

```bash
./safe-install.sh --with-science   # Re-clone K-Dense repo + rebuild cache + re-sync
```

---

## Token Efficiency — Skills Injection + Prompt Caching

All 317+ skills (~744KB / ~186K tokens, ECC + K-Dense) are injected into every `claude` session via `--append-system-prompt-file`. With `--with-curated` the total grows to ~800+ skills. This sounds expensive, but Claude Code's **prompt caching** makes it economical:

### How caching works

| Event | Cost at Opus pricing |
|-------|---------------------|
| Session 1 (cache miss) | ~$2.79 (186K × $15/MTok) |
| Session 2+ same day (cache hit) | ~$0.28 (186K × $1.50/MTok cache read) |
| Each conversation turn | Only new tokens in the exchange |

**5 sessions/day with caching: $2.79 + 4 × $0.28 = $3.91**
Without caching it would be $2.79 × 5 = $13.95. With caching: **72% cheaper.**

### What's already enabled

`setup-mcp.sh` sets `tengu_system_prompt_global_cache: true` in `~/.claude.json`. This persists the cache **across sessions** (not just within one session), so the system prompt (skills injection) is reused from cache as long as the file content doesn't change.

Running `./install.sh` on a new machine configures this automatically.

### Why full injection beats selective injection

Selective/on-demand loading requires the user to know which skills to activate. Full injection means Claude automatically applies relevant skills (TDD when writing tests, security review when touching auth, etc.) **without any explicit invocation** — which is the whole point.

---

## MCP Tool Enforcement

Three layers ensure Claude actually uses MCP tools instead of raw file scanning:

| Layer | Mechanism | Strength |
| ----- | --------- | -------- |
| `~/.claude/CLAUDE.md` | Global instructions loaded every session | Soft — can be ignored |
| Skills cache preamble | Injected at top of `combined-skills.txt` | Soft — reinforces CLAUDE.md |
| `hooks/codesight-redirect.sh` | PreToolUse hook blocks broad Glob/Grep | **Hard — actually stops the call** |

### How the hook works

When Claude attempts a broad codebase search (any `**` glob pattern or bare Glob in a codesight-enabled project), the hook:

1. Detects `.codesight/` exists in the project tree
2. Blocks the tool call (exit 2 → message sent back to Claude)
3. Tells Claude to call `codesight_get_summary` first
4. After the first reminder per session, allows all subsequent searches through (no repeated nagging)

```bash
# Hook fires on: Glob("**/*.ts"), Grep(path="/your/project", ...)
# Passes through: Read("/path/to/specific/file.ts"), Grep("specific-function-name")
```

Installed by `setup-hooks.sh`, wired into `install.sh` alongside `setup-claude-md.sh`.

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
| **macOS** | `~/Library/Application Support/Claude/claude_desktop_config.json` | ✅ Tested |
| **Linux** | `~/.config/Claude/claude_desktop_config.json` | ✅ Tested |
| **Windows** | `%APPDATA%\Claude\claude_desktop_config.json` | Supported via WSL (untested) |

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

### How to install skills

Skills are packaged as `.skill` files (zip format with sanitized YAML frontmatter) and uploaded via the Desktop app's built-in upload feature.

```bash
# 1. Package all skills as .skill files
./scripts/build-desktop-skills.sh                   # default: full tier
./scripts/build-desktop-skills.sh --tier standard    # fewer skills

# 2. Open the output folder
open configs/desktop-skills/
```

Then in Claude Desktop:

1. Go to **Customize** → **Skills**
2. Click **+** → **Upload a skill**
3. Select `.skill` files from `configs/desktop-skills/` (you can select multiple)

To update skills later (e.g. after `update-ecc.sh`), re-run `build-desktop-skills.sh` and re-upload.

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
| Skills injection | ~317 files via `--append-system-prompt-file` | 88 + personal + K-Dense via Project instructions |
| Prompt caching | `tengu_system_prompt_global_cache: true` | Built-in Project caching |
| Shell wrappers | `_claude_with_skills` in `.bashrc`/`.zshrc` | N/A (GUI app) |

---

## See Also

- `docs/TROUBLESHOOTING.md` — Common problems and solutions
- `~/.claude-everything-claude-code/` — Full ECC skills repository
- `~/.claude-scientific-skills/` — K-Dense scientific agent skills repository
- `~/.claude-everything-claude-code/mcp-configs/mcp-servers.json` — Complete MCP server reference
