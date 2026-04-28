# ai-skillweave

> Auto-learning agent harness: captures corrections live, mines session history for patterns, syncs ~450 skills across Claude/Codex/OpenClaw/Pi with MCP pre-configured.

One-command setup for all your Ollama agent harnesses: proper MCP servers, web tools, harness-specific configs — all portable and reproducible. Learns from your corrections automatically via real-time hooks and batch session analysis.

**~450 skills** on-disk across 5 sources — see [`docs/SKILLS-CATALOG.md`](docs/SKILLS-CATALOG.md) for a full categorized listing.

---

## Skill Sources

> **Skills in this repo are drawn from multiple open-source skill libraries**, each following the [Agent Skills](https://agentskills.io/) standard:

| Source | Skills | Notes |
|--------|--------|-------|
| [Everything Claude Code (ECC)](https://github.com/affaan-m/everything-claude-code) | 184 SKILL.md dirs | Community-maintained — testing, architecture, security, cloud, language patterns |
| [K-Dense scientific](https://github.com/K-Dense-AI/scientific-agent-skills) | 134 SKILL.md dirs | Bioinformatics, cheminformatics, drug discovery, clinical research, ML/AI |
| [ClawBio bioinformatics](https://github.com/ClawBio/ClawBio) | 56 SKILL.md dirs | Bioinformatics-native pipeline skills with executable Python scripts |
| [SkillGraph bioinformatics](https://github.com/variomeanalytics/bioinformatics-agent-skills) | MCP-served | Via MCP server with knowledge graph |
| Anthropic official | 17 SKILL.md dirs | Anthropic's official skills library |
| OpenAI Codex curated | 44 SKILL.md dirs | OpenAI's Codex skills collection |
| Personal learned | varies | BMO-style real-time capture (corrections detected live via hooks) + batch 4-stage pipeline |

`ai-skillweave`'s core contribution is **cross-harness delivery**: each skill library was originally designed for a single harness. This repo extends them so the same skills load natively into every `ollama launch` agent — OpenClaw, Pi, Codex, and Claude Code — each in the format that harness expects.

All sources are credited in the Skill Sources table above.

---

## Scientific Agent Skills — K-Dense

> **134 scientific and research skills from [K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills)** — covering bioinformatics, cheminformatics, drug discovery, clinical research, proteomics, medical imaging, ML/AI, materials science, physics, and 100+ scientific databases.

These skills follow the open [Agent Skills](https://agentskills.io/) standard and work with Claude Code, Cursor, Codex, and Gemini CLI. `ai-skillweave` extends them to all supported harnesses, just like ECC skills.

To install:

```bash
./safe-install.sh --with-science                    # ECC + K-Dense scientific skills
```



---

## Bioinformatics Agent Skills — Variome Analytics

> **Bioinformatics pipeline skills served via MCP from [variomeanalytics/bioinformatics-agent-skills](https://github.com/variomeanalytics/bioinformatics-agent-skills)** — covering variant analysis, drug discovery, single-cell RNA-seq, genome-wide association studies, and 15+ database query skills (ClinVar, gnomAD, COSMIC, Ensembl, UniProt, and more).

Unlike ECC and K-Dense which ship on-disk `SKILL.md` files, these skills are served dynamically via an **MCP server** (`skillgraph`) that provides:

- `get_skill` — Full skill documentation for any skill in the graph
- `list_skills` — List all skills, optionally filtered by domain
- `search_skills` — Keyword search across skill IDs, triggers, and tool names
- `get_transitions` — Upstream/downstream skill edges with paper counts and data types
- `find_path` — Shortest pipeline path between two skills
- `get_graph_stats` — Graph statistics (skill count, edges, domain breakdown)

This knowledge graph approach means you can ask "what pipeline takes me from FASTQ to DEGs?" and get a real answer with evidence — something on-disk skill files alone can't provide.

**Installation:**

```bash
# Add the SkillGraph MCP server (works out of the box after install.sh)
# It's already included in configs/claude-mcp-servers.json
./scripts/setup-mcp.sh --force   # re-apply MCP config to add skillgraph
```

---

## Bioinformatics Pipeline Skills — ClawBio

> **56 bioinformatics pipeline skills from [ClawBio/ClawBio](https://github.com/ClawBio/ClawBio)** — covering RNA-seq differential expression, VCF annotation, clinical variant reporting, single-cell orchestration, GWAS/PRS, HLA typing, methylation clocks, drug-target validation, and more.

Unlike ECC and K-Dense skills which are prompt-only `SKILL.md` files, ClawBio skills ship **executable Python scripts** alongside their skill definitions (172 `.py` files across 56 skills, plus 43 test directories). Each `SKILL.md` includes an `openclaw` metadata block with `uv` package requirements, so compatible harnesses can auto-install dependencies.

**Skill categories:**

| Category | Skills | Examples |
|----------|--------|---------|
| Genomics & Variants | 7 | `variant-annotation`, `vcf-annotator`, `fine-mapping`, `hla-typing`, `archaic-introgression` |
| Clinical & Pharma | 8 | `clinical-variant-reporter`, `clinpgx`, `pharmgx-reporter`, `nutrigx_advisor`, `drug-photo` |
| Transcriptomics | 6 | `rnaseq-de`, `scrna-orchestrator`, `scrna-embedding`, `de-summary`, `proteomics-de` |
| GWAS & Population | 6 | `gwas-lookup`, `gwas-prs`, `claw-ancestry-pca`, `mendelian-randomisation` |
| Data Integration | 6 | `bio-orchestrator`, `bioconductor-bridge`, `galaxy-bridge`, `bigquery-public` |
| Literature & Protocols | 5 | `pubmed-summariser`, `lit-synthesizer`, `bgpt-mcp`, `protocols-io` |
| Epigenomics | 1 | `methylation-clock` |
| Other | 17 | `seq-wrangler`, `equity-scorer`, `struct-predictor`, `ukb-navigator`, ... |

**Installation:**

```bash
./safe-install.sh --with-bio                         # ECC + ClawBio bioinformatics (56 skills)
./safe-install.sh --with-science --with-bio          # ECC + K-Dense + ClawBio
./safe-install.sh --with-science --with-bio --with-anthropic --with-codex  # Full: all sources
```

ClawBio is installed by default (`--with-bio` is on). To update, re-run with `--with-bio` to re-clone the latest from GitHub.



---

## Quick Start (New Machine)

```bash
# 1. Clone this repo
git clone https://github.com/chazhyseni/ai-skillweave
cd ai-skillweave

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
ollama launch copilot     # Copilot CLI + MCP servers
```

---

## What This Repo Does

| Component | What it configures |
|-----------|-------------------|
| **Claude Code MCP** | Adds 9 auto-configured servers to `~/.claude.json`: memory, sequential-thinking, context7, playwright, google-docs-editor, token-optimizer, codesight, skillgraph, beads |
| **OpenClaw** | Enables web tools + Ollama plugin in `~/.openclaw/openclaw.json` |
| **Pi** | Sets Ollama as provider + installs `pi-subagents` package |
| **Codex** | Configures `ollama-launch` provider + `danger-full-access` sandbox in `~/.codex/config.toml` |
| **Copilot CLI** | Configures MCP servers (including beads) in `~/.copilot/mcp-config.json` |
| **Ollama integrations** | Sets per-harness model mapping in `~/.ollama/config.json` (qwen3.6 default) |
| **Shell wrappers** | Adds `_*_with_skills` functions + aliases in `~/.bashrc` and/or `~/.zshrc` |
| **Claude Code skills** | Copies ECC SKILL.md files to `~/.claude/skills/` — visible via `/skills`, works with any launch method |
| **Lean skills cache** | Personal learned skills at `~/.claude/skills-cache/lean-skills.txt` — name + one operating principle per skill (~1100 tokens total). Full library cache (`combined-skills.txt`) kept for reference but never injected — Claude's 200K window means 5MB would crash every session |
| **bioSkills** | 438 bioinformatics skills from [GPTomics/bioSkills](https://github.com/GPTomics/bioSkills) cloned into `~/.claude/skills/` — available on-demand via the Skill tool, NOT injected into every session. Covers variant-calling, single-cell, spatial-transcriptomics, phylogenetics, GWAS, ATAC-seq, CRISPR, and 57 other categories |
| **Beads** | `bd` CLI + `beads-mcp` MCP server — cross-session work item tracking. `bd prime` gives AI-optimised project context at session start |
| **Learning pipeline scripts** | Copies `sync-learned-skills.sh`, `extract-conversation-skills.py`, `safe-install.sh` to `~/.claude/scripts/` so `learn-sync`/`learn-stats`/`learn-prune` aliases work from any directory |

---

## Repository Structure

```
ai-skillweave/
├── install.sh                    ← Master installer (run this)
├── safe-install.sh               ← ECC skills installer
├── extract-conversation-skills.py ← 4-stage learning pipeline (Ingestion→Learning→Consolidation→Output)
├── sync-learned-skills.sh        ← Sync learned skills + run pipeline (--stats, --prune, --sync-only)
│
├── hooks/                        ← Claude Code hooks (auto-installed by install.sh)
│   ├── codesight-redirect.sh     ← PreToolUse: redirect broad searches to codesight
│   ├── learning-capture.sh       ← UserPromptSubmit: BMO-style real-time correction capture
│   └── session-reflection.sh     ← Session end: consolidate captured events into skills
│
├── configs/                      ← Portable config templates
│   ├── claude-mcp-servers.json   ← MCP servers for Claude Code CLI
│   ├── claude-desktop-mcp-servers.json  ← MCP servers for Claude Desktop GUI
│   ├── copilot-mcp-config.json   ← MCP servers for Copilot CLI
│   ├── global-claude-md.md       ← Global CLAUDE.md template (MCP rules + beads workflow + conciseness)
│   ├── openclaw.json             ← OpenClaw config (web tools enabled)
│   ├── codex-config.toml         ← Codex ollama-launch provider config
│   ├── pi-settings.json          ← Pi agent settings
│   ├── ollama-integrations.json  ← Ollama integration→model mapping
│   └── zshrc-skills-block.sh     ← Shell skills layer block (reference/manual use)
│
├── scripts/                      ← Individual setup scripts
│   ├── setup-mcp.sh              ← Inject MCP into ~/.claude.json (CLI)
│   ├── setup-claude-md.sh        ← Install global CLAUDE.md (MCP rules + conciseness)
│   ├── setup-hooks.sh            ← Install PreToolUse hook (codesight-redirect)
│   ├── setup-learning-hook.sh    ← Install UserPromptSubmit hook (BMO learning capture)
│   ├── setup-beads.sh            ← Install beads CLI + beads-mcp + bd init (auto-installs Homebrew if needed)
│   ├── install-bioskills.sh      ← Clone GPTomics/bioSkills → ~/.claude/skills/ (438 on-demand bioinformatics skills)
│   ├── consolidate-learning.py   ← Consolidate captured events into SKILL.md files
│   ├── setup-claude-desktop.sh   ← Standalone: MCP + skills for Claude Desktop GUI
│   ├── build-desktop-skills.sh   ← Package .skill files for Desktop upload
│   ├── setup-openclaw.sh         ← Apply OpenClaw config
│   ├── setup-codex.sh            ← Apply Codex config
│   ├── setup-pi.sh               ← Apply Pi settings
│   ├── setup-copilot.sh          ← Apply Copilot CLI MCP config
│   ├── setup-ollama-config.sh    ← Apply Ollama integration→model mapping
│   ├── update-ecc.sh             ← Pull latest ECC + rebuild cache + learn-sync + re-sync harnesses
│   ├── disable-zscaler.sh        ← Disable Zscaler proxy
│   └── verify.sh                 ← Health check all components (beads, lean-skills, all harnesses)
│
├── docs/
│   ├── AUDIT.md                  ← MCP/subagent audit (what was fixed + why)
│   └── TROUBLESHOOTING.md        ← Common issues and fixes
│
└── shared-learning/
    └── learning.md               ← Cross-harness learned patterns log
```

---

## Platform Support

| Platform | Status | Shell | Notes |
|----------|--------|-------|-------|
| **macOS** | ✅ Tested | zsh (default) | Homebrew for dependencies |
| **Linux** | ✅ Tested | bash (default) | apt/dnf/pacman auto-detected |
| **Windows (WSL)** | ✅ Supported | bash | Run inside WSL — native Windows is not supported |

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
# Cloud models — no download needed, stream from Ollama's servers at inference time:
# Just use them directly: ollama run qwen3.5:cloud

# Local model — runs on your machine (~23GB download):
ollama pull qwen3.6                    # recommended local model
ollama pull gemma4:e4b                 # lightweight, good for subagents
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

> **Note:** OpenClaw, Pi, Codex, and Copilot are optional. `install.sh` will skip harnesses that aren't installed and show a warning. Ollama is also optional — the installer warns but continues without it.
>
> **Copilot CLI:** Copilot natively discovers SKILL.md files from `~/.claude/skills/` as its `personal-claude` source — no injection wrapper needed. It also reads `.github/skills`, `.agents/skills`, `~/.copilot/config/skills`, and `~/.agents/skills`. MCP servers (including beads) are configured in `~/.copilot/mcp-config.json` via `scripts/setup-copilot.sh`. You can see `~400 skills` in Copilot because the full ECC/K-Dense/ClawBio library (246 SKILL.md files) is loaded automatically at startup.

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
# Full setup — all harnesses, all skills (ECC + K-Dense scientific), default model
./install.sh

# Skip K-Dense scientific skills (faster, fewer skills)
./install.sh --without-science

# Use a local model instead (faster, no cloud dependency)
./install.sh --model qwen3.6
./install.sh --model gemma4:26b

# Configure only specific harnesses
./install.sh --only claude
./install.sh --only openclaw
./install.sh --only pi
./install.sh --only codex
./install.sh --only copilot
./install.sh --only beads

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
| `skillgraph` | Bioinformatics pipeline skills + knowledge graph via MCP — variant analysis, drug discovery, single-cell, 15+ databases |
| `beads` | Cross-session work item tracking — `bd prime` gives AI-optimised context at session start (injected after `setup-beads.sh` confirms `beads-mcp` is installed) |

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

Skills from **[Everything Claude Code (ECC)](https://github.com/affaan-m/everything-claude-code)** are the largest single source (184 SKILL.md dirs). ECC is a community-maintained library of production-ready AI agent skills covering testing, architecture, security, cloud deployment, language-specific patterns, and more.

ECC skills are structured Markdown prompts (`.md` files) that tell AI agents *how to think* about specific tasks — when to activate, how to approach the problem, examples, and pitfalls.

### Skill Sources

| Source | Skills | Notes |
|--------|--------|-------|
| ECC core | 184 SKILL.md dirs | From `affaan-m/everything-claude-code` |
| K-Dense scientific | 134 SKILL.md dirs | From `K-Dense-AI/scientific-agent-skills` |
| ClawBio bioinformatics | 56 SKILL.md dirs | From `ClawBio/ClawBio` — pipeline skills with Python scripts |
| SkillGraph bioinformatics | Bioinformatics pipeline skills | From `variomeanalytics/bioinformatics-agent-skills` via MCP server |
| Anthropic official | 17 SKILL.md dirs (85 total .md) | From Anthropic's official skills library |
| OpenAI Codex curated | 44 SKILL.md dirs (534 total .md) | From OpenAI's Codex skills collection |
| Personal learned | varies | BMO-style real-time capture (corrections detected live via hooks) + batch 4-stage pipeline |

### What Each Harness Gets

| Harness | Skills | How they load |
|---------|--------|--------------|
| `claude` / `ollama launch claude` | **~450 native** + lean skills cache | SKILL.md → `~/.claude/skills/` (native `/skills`) + personal learned skills via `lean-skills.txt` (~1-2K tokens, via `--append-system-prompt-file`) + MCP servers |
| `copilot` (Copilot CLI) | **~246 SKILL.md files** natively | Copilot's built-in skill discovery reads `~/.claude/skills/` as `personal-claude` source automatically — no wrapper needed. Also reads `.github/skills`, `~/.copilot/config/skills`. Disable individual skills via `disabledSkills` in `~/.copilot/settings.json`. Add extra dirs via `COPILOT_SKILLS_DIRS` env var. |
| `ollama launch openclaw` | **~450 skill dirs** | Real SKILL.md copies in `~/.openclaw/workspace/skills/`, YAML-sanitized |
| `ollama launch pi` | **~450 skill dirs** | Symlinks in `~/.pi/agent/skills/` |
| `ollama launch codex` | **~450 + 5 built-in** | YAML-sanitized copies in `~/.codex/skills/` + Codex system skills |

Native `~/.claude/skills/` installation means skills are visible via Claude Code's `/skills` command and load **regardless of launch method** (direct CLI, `ollama launch`, VSCode extension).

> **YAML sanitization:** Skills with block-scalar descriptions, extra metadata fields (author, version, tags), or nested YAML mappings are automatically sanitized without modifying source files.

### Cross-Harness Skill Sync

When you learn something useful in one session, sync it everywhere:
```bash
learn-sync          # Extract patterns + sync to all harnesses
learn-sync-dry      # Preview what would sync
learn-stats         # Show skill counts, feedback scores, decay status
learn-prune         # Archive low-signal skills (feedback × decay < 0.2)
```

---

## Harness Evolution — Self-Improving Skills

> Your harnesses get better over time. Corrections and preferences you state during sessions are captured in real-time and automatically distilled into concise, generalizable skills that load in every future session across every harness.

Two complementary learning approaches run in parallel:

### 1. BMO-Style Real-Time Capture (primary)

Inspired by [bmo-agent](https://github.com/joelhans/bmo-agent). A `UserPromptSubmit` hook (`hooks/learning-capture.sh`) fires on every message and detects learning events as they happen:

| Event type | Detection | Example |
|------------|-----------|---------|
| `correction` | "No,", "Actually…", "That's not what I meant" | "No, use absolute paths here" |
| `preference` | "I prefer…", "I always…", "I like…" | "I always want type hints in Python" |
| `pattern` | "best practice", "convention", "should always" | "Should always validate before pushing" |

Events are saved to `~/.claude/skills/learned/events/` as JSON. At session end (`hooks/session-reflection.sh`), `scripts/consolidate-learning.py` clusters similar events and writes SKILL.md files with **short, imperative names** (e.g. `verify-output-completeness`, `cite-published-research`).

```bash
# Manual consolidation (also runs automatically at session end)
python3 scripts/consolidate-learning.py
```

### 2. Batch Pipeline (secondary — runs on install/update)

For bulk distillation from conversation history. A 4-stage ALMA-inspired pipeline in `extract-conversation-skills.py`:

| Stage | What it does |
|-------|-------------|
| **1. Ingestion** | Parses conversation histories, classifies user corrections into memory types: `anti_pattern` (failed approaches), `heuristic` (successful strategies), `preference` (style), `domain_knowledge` (project-specific — **rejected**) |
| **2. Learning** | Groups similar corrections (Jaccard ≥ 0.5), requires **3+ unique sessions** (configurable via `--min-occurrences`), confidence = success × min(count/20, 1.0) + cross-project bonus, minimum 0.5 |
| **3. Consolidation** | Deduplicates (token overlap ≥ 0.85), abstracts raw corrections into **condition + strategy + anti-pattern** via keyword mapping or LLM distillation (`--llm`), quality gates reject empty/generic/single-project patterns |
| **4. Output** | Writes concise SKILL.md files with short imperative names (`verify-X`, `avoid-X`), YAML frontmatter (name, description, origin, tags, version, priority) |

**Quality-first design**: Without `--llm`, only skills matching known condition templates are written — producing 0 skills is better than keyword soup. With `--llm`, Ollama distills corrections into proper condition+strategy+anti-pattern form, and generates short semantic names like `cite-published-research-dois` (not sentence fragments).

### Skill format

Every learned skill follows ECC-compatible structure — frontmatter, `When to Use`, `Operating Principles`, `Anti-patterns`, `Provenance`:

```markdown
---
name: evidence-based-claims
description: Require published evidence for scientific claims. Learned from 5 sessions across 3 projects.
origin: conversation-pipeline
tags: [learned, anti_pattern, universal]
version: 1.0.0
priority: high
---

# Evidence Based Claims

## When to Use

Making scientific or factual claims that could be verified against literature.

## Operating Principles

1. Cite specific papers (DOI, PMID) or explicitly state "no published evidence found".
2. Distinguish model output from experimental data.
3. Flag claims that lack published support.

## Anti-patterns

- Fabricating citations or DOIs.
- Presenting unverified results as established findings.
- Claiming model output as experimental data.

## Provenance

- **Confidence:** 0.72
- **Unique sessions:** 5
- **Projects:** 3
- **Harnesses:** 2
- **First observed:** 2025-04-10
```

### Feedback & decay

- `.usage.json` tracks how often each skill is loaded, used, or ignored
- **Feedback score** = (uses − ignores) / total loads (neutral 0.5 until 5 samples)
- **Decay factor** = exp(−0.693 × days / 90) — skills unused for 90 days halve in relevance
- Skills with feedback × decay < 0.2 get **archived** (not deleted) to `learned/archived/`

### Integration

Learning runs automatically via two paths:
- **Real-time**: `hooks/learning-capture.sh` fires on every `UserPromptSubmit`, events consolidated at session end by `hooks/session-reflection.sh`
- **Batch**: On `safe-install.sh` (use `--no-learn` to skip), on `update-ecc.sh` (Step 4: learn-sync), or manually via `learn-sync` alias
- Skills propagate to all harnesses via `sync-learned-skills.sh`

Both paths write to `~/.claude/skills/learned/` using the same ECC-compatible SKILL.md format.

Only **2 of 4 memory types** produce generalizable skills: `heuristic` and `anti_pattern`. Preferences are per-user; domain knowledge is project-specific. This ensures learned skills are universally applicable, not project noise.

### Installing ECC

> **Note on defaults:** bare `./safe-install.sh` installs ECC + K-Dense scientific skills + ClawBio bioinformatics (all three are on by default). Use `--without-science` or `--without-bio` to skip a source.

```bash
./safe-install.sh                                    # ECC + K-Dense + ClawBio (default — all three)
./safe-install.sh --without-science --without-bio    # ECC only (fastest)
./safe-install.sh --with-science                     # ECC + K-Dense scientific skills (134 skills)
./safe-install.sh --with-bio                         # ECC + ClawBio bioinformatics (56 skills)
./safe-install.sh --with-curated                     # Also include OpenAI Codex curated skills
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

To update ClawBio bioinformatics skills, re-run with `--with-bio`:

```bash
./safe-install.sh --with-bio   # Re-clone ClawBio repo + rebuild cache + re-sync
```

---

## How skills stay available without burning tokens

The key is **deferred loading**: skills are indexed (name only in system prompt, ~5 tokens each), not pre-loaded. Full content only loads when a skill is actually invoked.

### The three layers

| Layer | What's in context | Token cost |
|-------|------------------|------------|
| **Skill index** (always) | ~500 skill names in the available-skills list | ~2500 tokens, cached after first turn |
| **lean-skills.txt** (ollama/claude CLI only) | Name + one operating principle per learned skill | ~1100 tokens (was 5750 before v2.1) |
| **Skill content** (on demand) | Full SKILL.md loaded when you invoke a skill | 0 tokens unless used |

### Why this works

```
Session start:   [skill names only] ←→ "variant-calling/gatk-variant-calling"   ~5 tokens
Skill invoked:   [full SKILL.md loaded] ←→ 200+ lines of code patterns          ~2000 tokens
Session with no skills invoked: pay only for the index, not the content
```

**bioSkills (438 skills, ~100KB each):** Without deferred loading, installing these would add ~40MB to every session. With deferred loading, they cost ~0 tokens until invoked.

### How skills load in each harness

| Harness | How skills are loaded | All ~950 skills? |
|---------|----------------------|-----------------|
| Claude Code | Native deferred loading from `~/.claude/skills/` — content fetched on demand | ✅ Yes |
| Copilot CLI | Native discovery from `~/.claude/skills/` | ✅ Yes |
| Codex | Synced to `~/.codex/skills/` by `update-ecc.sh` | ✅ Yes |
| Pi | Linked to `~/.pi/agent/skills/` | ✅ Yes |
| OpenClaw | Copied to `~/.openclaw/workspace/skills/` | ✅ Yes |
| `claude` CLI | lean-skills.txt (~1100 tokens) appended at launch | ✅ Learned skills |

### lean-skills.txt (for `claude` CLI + ollama sessions)

Injects a brief summary of your personal learned skills so the model knows they exist:

| File | Size | Tokens | Used for |
|------|------|--------|----------|
| `lean-skills.txt` | ~3KB | ~1100 | Injected via `--append-system-prompt-file` at session start |
| `combined-skills.txt` | ~5.5MB | ~1.375M | Reference / local search only — never injected |

**Prompt caching:** Active via `tengu_system_prompt_global_cache: true` in `~/.claude.json` — the system prompt (including skill index + lean-skills) is cached after session 1, costing ~90% less on subsequent turns.

### What ai-skillweave can't reduce

The Claude Code plugin ecosystem (MCP server instructions, deferred tools manifest) adds ~10–20K tokens to every session. This comes from the installed plugins and is not controlled by ai-skillweave. Prompt caching amortizes this cost; removing unused plugins reduces it permanently.

---

## MCP Tool Enforcement

Three layers ensure Claude actually uses MCP tools instead of raw file scanning:

| Layer | Mechanism | Strength |
| ----- | --------- | -------- |
| `~/.claude/CLAUDE.md` | Global instructions loaded every session | Soft — can be ignored |
| Lean skills preamble | Short directive injected at top of `lean-skills.txt` | Soft — reinforces CLAUDE.md |
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

Ollama offers two model types: **cloud models** (hosted on Ollama's servers, no local GPU needed, require internet) and **local models** (downloaded and run on your machine).

### Cloud Models

| Model | Context | Best for |
|-------|---------|---------|
| `qwen3.5:cloud` | 256K | Most capable cloud model — 397B MoE, vision + tools + thinking |
| `gemma4:31b-cloud` | 256K | Google's frontier model — strong reasoning, coding, vision |
| `glm-5.1:cloud` | — | Zhipu's flagship — top SWE-Bench Pro, agentic coding |
| `minimax-m2.7:cloud` | — | MiniMax M2 — coding, agentic workflows, professional tasks |
| `nemotron-3-super:cloud` | — | NVIDIA 120B MoE (12B active) — multi-agent applications |

### Local Models

| Model | Context | Best for |
|-------|---------|---------|
| `qwen3.6` | 256K | MoE 36B — agentic coding, general-purpose (**Recommended**) |
| `gemma4:26b` | 128K | MoE 26B (4B active) — reasoning + vision, efficient |
| `devstral-small-2` | 128K | Mistral 24B — software engineering, codebase exploration |
| `qwen3:30b` | 256K | MoE 30B (3B active) — fast reasoning |
| `gemma4:e4b` | 128K | MoE 4B — edge/on-device, lightweight agent tasks |

> Context windows and model details from [ollama.com/library](https://ollama.com/library). Run `ollama show <model>` locally to verify.

```bash
# Cloud models — no download needed, stream at inference time:
# Use directly: ollama run qwen3.5:cloud

# Local models — download to run on your machine:
ollama pull qwen3.6
ollama pull gemma4:e4b           # lightweight, good for subagents
```

```bash
# Configure for Claude Code (large context tasks):
./install.sh --model qwen3.6

# Configure for OpenClaw / Pi / Codex (cloud reasoning):
./install.sh --model qwen3.5:cloud

# Add a lightweight local fallback (no internet needed):
ollama pull gemma4:e4b
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

`codesight` runs as an MCP server — one of the 9 servers applied automatically by `./install.sh`:

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

**MCP servers** (6 from template + any API-key servers found in your CLI config — zero token cost until invoked):

| Server | Purpose |
|--------|---------|
| `codesight` | Codebase summaries, routes, schema, hot files |
| `context7` | Live library/framework docs |
| `memory` | Persistent memory across sessions |
| `sequential-thinking` | Chain-of-thought reasoning |
| `token-optimizer` | 95%+ context reduction via deduplication |
| `playwright` | Browser automation |
| `github` | GitHub API (copied from CLI config if configured) |
| `exa-web-search` | Neural web search (copied from CLI config if configured) |

> **Note:** `skillgraph` (bioinformatics skills via MCP) is an HTTP-type server. Claude Desktop's config file does not support remote/HTTP servers — add it via **Settings → Integrations** in the Desktop UI instead. It works natively in Claude Code CLI (`~/.claude.json`).

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
| MCP servers | 9 auto (incl. beads) + manual API-key servers | 6 auto + API-key servers copied from CLI; skillgraph via Settings → Integrations |
| Skills injection | ~450 files via native `/skills` + lean cache (~1-2K tokens) | 88 + personal + K-Dense via Project instructions |
| Prompt caching | `tengu_system_prompt_global_cache: true` | Built-in Project caching |
| Shell wrappers | `_claude_with_skills` in `.bashrc`/`.zshrc` | N/A (GUI app) |

---

## Beads Integration

> **Powered by [beads](https://github.com/gastownhall/beads)** — AI-native cross-session work item tracking. Works with every harness (Claude Code, Codex, Copilot, OpenClaw, Pi) via MCP.

### What beads does

Beads lets you create, track, and share work items across AI coding sessions. Unlike session memory (which is per-harness), beads items persist in your project via `AGENTS.md` — a harness-agnostic file every AI tool reads.

| Command | What it does |
|---------|-------------|
| `bd prime` | Gives Claude an AI-optimised context dump of all open work items — run at session start |
| `bd ready` | List items ready to work on |
| `bd create "task"` | Create a new work item |
| `bd update <id> "status"` | Update an item's status |
| `bd close <id>` | Mark an item complete |

### Installation

`scripts/setup-beads.sh` is called automatically by `install.sh` (Step 7). It:

1. Checks for Homebrew — installs it if missing and stdin is a TTY (interactive only; CI/non-interactive installs skip if brew absent)
2. Installs `beads` via `brew install beads` (macOS) or the official curl script (Linux)
3. Installs `beads-mcp` via `uv tool install beads-mcp` (with `pip3 install --user beads-mcp` fallback)
4. Injects the `beads` MCP entry into `~/.claude.json` and `~/.copilot/mcp-config.json` (only after confirming beads-mcp is installed; skips if already present)
5. Runs `bd init --quiet --stealth` to initialise beads in the current repo

```bash
# Run just beads setup
./install.sh --only beads

# Or standalone
scripts/setup-beads.sh
scripts/setup-beads.sh --force    # overwrite existing beads MCP entry
```

### Stealth mode

`--stealth` means `.beads/` is kept local (in `.gitignore`) — your beads items don't get committed to the project repo. `AGENTS.md` is still updated by `bd init` and is safe to commit.

### Harness-agnostic design

The MCP server (`beads-mcp`) makes beads available in any harness that loads MCP configs: Claude Code (via `~/.claude.json`) and Copilot CLI (via `~/.copilot/mcp-config.json`). For OpenClaw, Pi, and Codex, `bd prime` output can be pasted directly into the session — the `AGENTS.md` file is what matters for cross-session persistence in those harnesses.

---

## See Also

- `docs/TROUBLESHOOTING.md` — Common problems and solutions
- `~/.claude-everything-claude-code/` — Full ECC skills repository
- `~/.claude-scientific-skills/` — K-Dense scientific agent skills repository
- `~/.claude-clawbio-skills/` — ClawBio bioinformatics pipeline skills repository
- [ClawBio/ClawBio](https://github.com/ClawBio/ClawBio) — Bioinformatics-native pipeline skills with executable Python scripts
- [variomeanalytics/bioinformatics-agent-skills](https://github.com/variomeanalytics/bioinformatics-agent-skills) — Bioinformatics pipeline skills + knowledge graph (MCP)
- `~/.claude-everything-claude-code/mcp-configs/mcp-servers.json` — Complete MCP server reference
