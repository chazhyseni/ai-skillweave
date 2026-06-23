# ai-skillweave

> Auto-learning agent harness: captures corrections live, mines session history for patterns, syncs skills across Claude/Codex/OpenClaw/Pi/Copilot/Hermes with MCP pre-configured.

One-command setup for all your Ollama agent harnesses: proper MCP servers, web tools, harness-specific configs — all portable and reproducible. Learns from your corrections automatically via real-time hooks and a batched learning pipeline that distills conversations into skills 30-50× faster than naive LLM calls.

**2,652 unique skills, delivered to all 6 harnesses** from 15 upstream repos: [OpenClaw-Medical](https://github.com/FreedomIntelligence/OpenClaw-Medical-Skills) (896 clinical), [operon](https://github.com/swaruplab/operon) (556 protocols), [bioSkills](https://github.com/GPTomics/bioSkills) (546, 63 categories), [ECC](https://github.com/affaan-m/everything-claude-code) (272), [SciAgent](https://github.com/jaechang-hits/SciAgent-Skills) (197), [ToolUniverse](https://github.com/mims-harvard/ToolUniverse) (150 drug discovery), [K-Dense](https://github.com/K-Dense-AI/scientific-agent-skills) (147), [ClawBio](https://github.com/ClawBio/ClawBio) (90), [DeepMind science-skills](https://github.com/google-deepmind/science-skills) (37), [Bipartite](https://github.com/matsen/bipartite) (37), [BioNeMo](https://github.com/NVIDIA-BioNeMo/bionemo-agent-toolkit) (35 GPU-accelerated bio), [Nature-Paper](https://github.com/Boom5426/Nature-Paper-Skills) (18 manuscript), [Anthropic](https://github.com/anthropics/skills) (17), [Codex curated](https://github.com/openai/skills) (44), [life-sciences](https://github.com/anthropics/life-sciences) (6). See [`docs/SKILLS-CATALOG.md`](docs/SKILLS-CATALOG.md) for the full per-source breakdown.

---

## Skill Sources

> Each source follows the [Agent Skills](https://agentskills.io/) standard (SKILL.md with `name` + `description` frontmatter):

| Source | On-disk | Net-new | Notes |
|--------|--------:|--------:|-------|
| [OpenClaw-Medical](https://github.com/FreedomIntelligence/OpenClaw-Medical-Skills) | 896 | 708 | Clinical workflows, genomics, drug discovery, regulatory — meta-aggregated from 12+ repos |
| [operon](https://github.com/swaruplab/operon) | 556 | 389 | Bioinformatics protocols (RNA-seq, scRNA-seq, ATAC-seq, ChIP-seq, WGS/WES, spatial, proteomics, GWAS) |
| [bioSkills](https://github.com/GPTomics/bioSkills) | 546 | 514 | 63 bioinformatics categories (RNA-seq, variants, ChIP-seq, scRNA-seq, spatial, Hi-C, proteomics, CRISPR, metabolomics, multi-omics) |
| [ECC](https://github.com/affaan-m/everything-claude-code) | 272 | 272 | Testing, architecture, security, cloud, language patterns (+ 92 slash-commands + 67 sub-agents, Claude-only) |
| [SciAgent](https://github.com/jaechang-hits/SciAgent-Skills) | 197 | 136 | Genomics, proteomics, structural biology, drug discovery, systems biology, biostatistics, scientific writing |
| [ToolUniverse](https://github.com/mims-harvard/ToolUniverse) | 150 | 150 | Drug discovery, precision oncology, rare-disease diagnosis; wraps 1,000+ ML models + datasets |
| [K-Dense](https://github.com/K-Dense-AI/scientific-agent-skills) | 147 | 146 | Bioinformatics, cheminformatics, drug discovery, clinical research, proteomics, 100+ scientific databases |
| [ClawBio](https://github.com/ClawBio/ClawBio) | 90 | 90 | Bioinformatics pipelines with executable Python scripts (398 `.py` files) |
| [DeepMind](https://github.com/google-deepmind/science-skills) | 37 | 37 | AlphaGenome, AlphaFold DB, UniProt, Ensembl, gnomAD, GTEx, ClinVar, ChEMBL, PubChem, PDB |
| [Bipartite](https://github.com/matsen/bipartite) | 37 | 37 | Research workflow CLI (`bip`) — manuscripts, literature, EPIC orchestration, PR review (+ 16 subagent definitions) |
| [BioNeMo](https://github.com/NVIDIA-BioNeMo/bionemo-agent-toolkit) | 35 | 33 | NVIDIA GPU-accelerated bio: Boltz-2, OpenFold2/3, RFdiffusion, ProteinMPNN, DiffDock, MolMIM, GenMol, Evo2, MSA-Search, Parabricks |
| [Nature-Paper](https://github.com/Boom5426/Nature-Paper-Skills) | 18 | 17 | Nature-style manuscript workflow: drafting, revision, figure planning, citation/reference audit, data-availability, submission audit, rebuttal, Nature portfolio playbook |
| [Anthropic](https://github.com/anthropics/skills) | 17 | 13 | Official Anthropic reference skills |
| [life-sciences](https://github.com/anthropics/life-sciences) | 6 | 5 | Single-cell RNA QC, Nextflow development, clinical-trial protocol, scientific problem selection |
| [Codex curated](https://github.com/openai/skills) | 44 | 0 | OpenAI Codex curated skills — live under hidden dirs and overlap ECC, so 0 net-new to the pool; ship natively with the Codex harness |

**Total: 2,652 unique skills** delivered to all 6 harnesses. On-disk counts overlap across sources; *net-new* is each source's deduplicated contribution (the net-new column plus 105 imported `claude_extras` sums to 2,652). Two further sources are queried live rather than installed on disk:

| Source | Delivery | Notes |
|--------|----------|-------|
| [SkillGraph](https://github.com/variomeanalytics/bioinformatics-agent-skills) | MCP-served | Bioinformatics knowledge graph via the `skillgraph` MCP server — queried on demand, never on disk |
| Personal learned | grows | Auto-extracted from your own conversation corrections via the batched 4-stage pipeline |

`ai-skillweave`'s core contribution is **cross-harness delivery**: it merges 15 skill libraries — most built for Claude Code or the portable [Agent Skills](https://agentskills.io/) format — into one deduplicated pool, then installs that pool into each harness's *native* skills directory, in the on-disk format that harness expects (real files, symlinks, or YAML-sanitized copies as needed). The same 2,652 skills then load in Claude Code, OpenClaw, Pi, Codex, Copilot, and Hermes — regardless of launch method.

---

## Scientific Agent Skills — K-Dense

> **147 skills from [K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills)** — covering bioinformatics, cheminformatics, drug discovery, clinical research, proteomics, medical imaging, ML/AI, materials science, physics, and 100+ scientific databases.

```bash
./safe-install.sh --with-science    # Clone K-Dense repo into ~/.claude-scientific-skills/
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

> **90 bioinformatics pipeline skills from [ClawBio/ClawBio](https://github.com/ClawBio/ClawBio)** — covering RNA-seq differential expression, VCF annotation, clinical variant reporting, single-cell orchestration, GWAS/PRS, HLA typing, methylation clocks, drug-target validation, and more.

Unlike ECC and K-Dense skills which are prompt-only `SKILL.md` files, ClawBio skills ship **executable Python scripts** alongside their skill definitions (398 `.py` files across 90 skills, plus 357 markdown files). Each `SKILL.md` includes an `openclaw` metadata block with `uv` package requirements, so compatible harnesses can auto-install dependencies.

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
./safe-install.sh --with-bio                         # ECC + ClawBio bioinformatics (90 skills)
./safe-install.sh --with-science --with-bio          # ECC + K-Dense + ClawBio
./safe-install.sh --with-science --with-bio --with-anthropic --with-codex  # Full: all sources
```

ClawBio is installed by default (`--with-bio` is on). To update, re-run with `--with-bio` to re-clone the latest from GitHub.


## Research Workflow Skills — Bipartite

> **37 research workflow skills from [matsen/bipartite](https://github.com/matsen/bipartite)** — manuscript sessions, literature management, EPIC orchestration, PR review, and workflow coordination. Also installs 16 subagent definitions (issue-lead, code-reviewers, proof-readers, tex-checkers, etc.) into `~/.claude/agents/`.

Bipartite is a Go CLI (`bip`) plus Claude Code skills for connecting research programs to the outside world. It operates on a "nexus" (a git-backed JSONL directory) that stores your paper library, project context, and workflow coordination data. The skills cover five areas:

- **Manuscript sessions** (`bip-ms`, `bip-ms-poll`, `bip-ms-audit`, `bip-ms-sweep`, `bip-ms-tuckin`) — cold-start dashboards for TeX repositories
- **Literature management** (`bip-lit`, `bip-lit-edges`, `bip-lit-extract`, `bip-lit-import`) — search, import, cite, and build knowledge graphs from Semantic Scholar + Asta
- **EPIC orchestration** (`bip-epic`, `bip-epic-spawn`, `bip-epic-poll`, `bip-epic-handoff`, `bip-epic-check`, `bip-epic-tuckin`, `bip-epic-prepare-reboot`, `bip-epic-recover`) — conductor/worker pattern for managing Claude Code sessions across clones
- **Issue & PR management** (`bip-issue-check`, `bip-issue-file`, `bip-issue-next`, `bip-issue-update`, `bip-issue-work`, `bip-pr-check`, `bip-pr-review`, `bip-pr-land`) — GitHub issue lifecycle + pre-merge quality checklist
- **Workflow coordination** (`bip-checkin`, `bip-digest`, `bip-narrative`, `bip-spawn`, `bip-scout`, `bip-board`, `bip-comment-check`, `bip-decay-audit`, `bip-kaizen`, `bip-plan`, `bip-marimo`, `bip-tmux`) — cross-repo check-ins, Slack digests, server resource scouting

**Installation** (requires Go 1.24+):

```bash
git clone https://github.com/matsen/bipartite ~/.claude-bipartite
cd ~/.claude-bipartite
make install
```

This installs the `bip` CLI to `~/go/bin/bip` and symlinks 37 skills + 16 agents into `~/.claude/`. The `update-ecc.sh` sync script automatically picks up bipartite as a source and distributes the skills to all 6 harnesses.

See [`docs/SKILLS-CATALOG.md`](docs/SKILLS-CATALOG.md) → the Bipartite section for the full list of all 37 skills grouped by functional area.


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
| **Claude Code skills** | Copies all 15 skill sources (OpenClaw-Medical, operon, bioSkills, ECC, SciAgent, ToolUniverse, K-Dense, ClawBio, DeepMind, Bipartite, BioNeMo, Nature-Paper, Anthropic, life-sciences, Codex curated) to `~/.claude/skills/` — 2,652 unique skills, visible via `/skills`, works with any launch method |
| **Lean skills cache** | Top 50 learned skills by confidence in `~/.claude/skills-cache/lean-skills.txt` (~13 KB, ~3K tokens, capped), injected at session start. Full library cache (`combined-skills.txt`, ~7 MB) is kept for local search only — never injected |
| **bioSkills** | 546 bioinformatics skills (63 categories) from [GPTomics/bioSkills](https://github.com/GPTomics/bioSkills) cloned into `~/.claude/skills/` — available on demand via the Skill tool, NOT injected into every session. Categories: variant-calling, single-cell, spatial-transcriptomics, phylogenetics, atac-seq, crispr-screens, workflows, and 56 more |
| **Beads** | `bd` CLI + `beads-mcp` MCP server — cross-session work item tracking. `bd prime` gives AI-optimised project context at session start |
| **Learning pipeline scripts** | Copies `sync-learned-skills.sh`, `extract-conversation-skills.py`, `safe-install.sh` to `~/.claude/scripts/` so `learn-sync`/`learn-stats`/`learn-prune` aliases work from any directory |

---

## Repository Structure

```
ai-skillweave/
├── install.sh                    ← Master installer (run this)
├── safe-install.sh               ← ECC skills installer
├── extract-conversation-skills.py ← 4-stage learning pipeline + batched LLM distillation (Ingestion→Learning→Consolidation→Output; 30-50× faster than naive via 20-group batches + 16 workers + HTTP connection pooling)
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
│   ├── install-bioskills.sh      ← Clone GPTomics/bioSkills → ~/.claude/skills/ (546 on-demand bioinformatics skills, 63 categories)
│   ├── consolidate-learning.py   ← Consolidate captured events into SKILL.md files
│   ├── setup-claude-desktop.sh   ← Standalone: MCP + skills for Claude Desktop GUI
│   ├── build-desktop-skills.sh   ← Package .skill files for Desktop upload
│   ├── setup-openclaw.sh         ← Apply OpenClaw config
│   ├── setup-codex.sh            ← Apply Codex config
│   ├── setup-pi.sh               ← Apply Pi settings
│   ├── setup-copilot.sh          ← Apply Copilot CLI MCP config
│   ├── setup-copilot-skills.sh   ← Bridge Copilot CLI to the cross-harness skill pool (symlink + COPILOT_SKILLS_DIRS)
│   ├── setup-ollama-config.sh    ← Apply Ollama integration→model mapping
│   ├── update-ecc.sh             ← Pull latest ECC + rebuild cache + re-sync harnesses (handles Codex 64-char names + broken symlinks)
│   ├── disable-zscaler.sh        ← Disable Zscaler proxy
│   └── verify.sh                 ← Health check all components (beads, lean-skills, all harnesses)
│
├── docs/
│   ├── SKILLS-CATALOG.md         ← Per-source skill listing + category breakdown + learning pipeline
│   ├── TROUBLESHOOTING.md        ← Common issues and fixes (Copilot bridge, context overflow, MCP failures)
│   ├── x-thread.md               ← X/Twitter thread (5 posts) for project announcements
│   └── linkedin-post.md          ← LinkedIn announcement post
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
> **Copilot CLI:** `scripts/setup-copilot-skills.sh` bridges Copilot to the cross-harness skill pool. It installs a `~/.copilot/config/skills -> ~/.claude/skills` symlink (zero-duplication, native Copilot path), exports `COPILOT_SKILLS_DIRS="$HOME/.claude/skills:$HOME/.pi/agent/skills"` in your shell rc, and refreshes the `_copilot_with_skills()` wrapper inline. Copilot's own loader also reads `~/.claude/skills/` directly as `personal-claude` — that path is the fallback if the bridge is not installed. MCP servers (including beads) are configured in `~/.copilot/mcp-config.json` via `scripts/setup-copilot.sh`.

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
- Skills are loaded from `~/.openclaw/workspace/skills/` (all skills copied there)

---

## Skills — Cross-Harness Delivery

Skills are structured Markdown prompts (SKILL.md files) that tell AI agents *how to think* about a task — when to activate, how to approach the problem, worked examples, and pitfalls. The largest single source is [OpenClaw-Medical](https://github.com/FreedomIntelligence/OpenClaw-Medical-Skills) (896 skills), followed by [operon](https://github.com/swaruplab/operon) (556 protocols), [bioSkills](https://github.com/GPTomics/bioSkills) (546, 63 categories), and [ECC](https://github.com/affaan-m/everything-claude-code) (272).

### What Each Harness Gets

| Harness | Files delivered | Delivery |
|---------|----------------:|----------|
| `claude` / `ollama launch claude` | 3,265 | Native `~/.claude/skills/` — loaded on demand via `/skills`. Top 50 learned skills injected via `lean-skills.txt` (~3K tokens) at launch. |
| `ollama launch openclaw` | 3,310 | Real file copies in `~/.openclaw/workspace/skills/`. |
| `ollama launch codex` | 3,318 | YAML-sanitized copies + symlinks in `~/.codex/skills/`. Codex flattens depth-3 to depth-1; the 64-char directory-name limit is defensive (no current skill exceeds it). |
| `ollama launch pi` | 3,345 | Symlinks in `~/.pi/agent/skills/` to source repos, plus 61 Pi-specific curated copies. |
| `copilot` (Copilot CLI) | 3,265 | Bridged by `setup-copilot-skills.sh`: a `~/.copilot/config/skills → ~/.claude/skills` symlink plus the `COPILOT_SKILLS_DIRS` env var. |
| Hermes (`~/.hermes/skills/`) | 3,675 | Real file copies into a dedicated `~/.hermes/skills/ai-skillweave/` category (the 2,652 pool); Hermes's native toolsets and its `openclaw-imports` staging set stay untouched. |

All six draw from the same **2,652 unique skills**. The per-harness file counts exceed 2,652 because each also includes that harness's native/bundled skills, the learned-skills cache, and a few duplicate-name copies the install retains — they are file counts, not unique-skill counts.

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

For bulk distillation from conversation history. A 4-stage ALMA-inspired pipeline in `extract-conversation-skills.py` (see *Performance methodology* below for the 30-50× speedup that comes from batched LLM distillation + 16 workers + HTTP connection pooling):

| Stage | What it does |
|-------|-------------|
| **1. Ingestion** | Parses conversation histories, classifies user corrections into memory types: `anti_pattern` (failed approaches), `heuristic` (successful strategies), `preference` (style), `domain_knowledge` (project-specific — **rejected**) |
| **2. Learning** | Groups similar corrections (Jaccard ≥ 0.5), requires **3+ unique sessions** (configurable via `--min-occurrences`), confidence = success × min(count/20, 1.0) + cross-project bonus, minimum 0.5 |
| **3. Consolidation** | Deduplicates (token overlap ≥ 0.85), abstracts raw corrections into **condition + strategy + anti-pattern** via keyword mapping or LLM distillation (`--llm`), quality gates reject empty/generic/single-project patterns |
| **4. Output** | Writes concise SKILL.md files with short imperative names (`verify-X`, `avoid-X`), YAML frontmatter (name, description, origin, tags, version, priority) |

**Quality-first design**: Without `--llm`, only skills matching known condition templates are written — producing 0 skills is better than keyword soup. With `--llm`, Ollama distills corrections into proper condition+strategy+anti-pattern form, and generates short semantic names like `cite-published-research-dois` (not sentence fragments).

#### Performance methodology — what changed

The naive `extract-conversation-skills.py` design called Ollama **once per correction group**: 580 groups × ~30 s each = ~4.8 hours of sequential LLM calls. Five design choices made this tractable on real hardware:

| # | Innovation | What it does | Effect |
|---|------------|--------------|--------|
| 1 | **Batched LLM distillation** | `_llm_distill_batch()` packs 20 groups into a single Ollama prompt and asks for one JSON array back, instead of N separate calls. Each group is still validated independently. | **20× fewer LLM calls** (580 → 29) |
| 2 | **HTTP connection pooling** | A single `requests.Session()` is reused across all batch calls in the loop, instead of opening a fresh TCP connection per request. | **Eliminates TCP/TLS handshake cost** (~50-100 ms saved per call, 29 calls × ~75 ms = ~2 s) |
| 3 | **Parallel batch workers (16)** | A `ThreadPoolExecutor(max_workers=16)` runs batches concurrently against Ollama. Ollama queues extras gracefully — no back-pressure needed. | **16× wall-clock speedup** for the distillation stage |
| 4 | **Isolated learning venv (`~/.claude/.venv`)** | The script's `_ensure_deps()` creates an isolated Python venv at `~/.claude/.venv` (not the system Python, not the repo venv) for `scikit-learn`, `numpy`, `requests`. Uses `uv` when available (PEP 668-safe on macOS Homebrew Python 3.12+), falls back to `pip install --user`. Re-execs itself with the venv python if needed. | **No conflicts with system packages**, no PEP 668 errors on externally-managed Python installs |
| 5 | **Lazy imports inside the hot path** | `import requests`, `import json` are imported inside `_llm_distill_batch()` (not at module top), so users running `--no-llm` don't pay the import cost and don't crash on a missing `requests` for unrelated paths. | **Avoids top-level import errors** when only the keyword-based code path is used |

**Combined speedup:** ~580 groups that would have taken ~4.8 hours now complete in **~2-5 minutes** on a modern machine — a **30-50× end-to-end improvement**. The number of LLM calls is constant (29) regardless of input size past one batch.

**Fallback behavior:** If a batch fails to parse JSON, the function falls back to per-group distillation for just that batch — gracefully degrading rather than aborting the whole run. If Ollama is unavailable, the keyword-mapping path (no LLM) is used as before.

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

### Installing Skills

> **Note on defaults:** bare `./safe-install.sh` installs ECC + K-Dense + ClawBio + bioSkills (all four are on by default). Use `--without-science`, `--without-bio`, or `--without-bioskills` to skip a source.

```bash
./safe-install.sh                                    # ECC + K-Dense (147) + ClawBio + bioSkills (all on by default)
./safe-install.sh --without-science --without-bio    # ECC only (fastest)
./safe-install.sh --with-science                     # Clone K-Dense repo (147 skills) into ~/.claude-scientific-skills/
./safe-install.sh --with-bio                         # Also include ClawBio bioinformatics (90 skills with Python scripts)
./safe-install.sh --with-curated                     # Also include OpenAI Codex curated skills (44 in upstream; overlap ECC, ship with the Codex harness)
```

### Keeping Skills Up to Date

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

The key is **deferred loading**: skills are indexed (name only in the system prompt, ~5 tokens each), not pre-loaded. Full content loads only when a skill is actually invoked.

### The three layers

| Layer | What's in context | Token cost |
|-------|------------------|------------|
| **Skill index** (always) | Every skill name in the available-skills list (2,652 unique; ~3,300 per harness with duplicates) | ~7,500 tokens, cached after the first turn |
| **lean-skills.txt** (ollama/claude CLI only) | Name + one operating principle per learned skill (top 50 by confidence) | ~3K tokens (hard cap) |
| **Skill content** (on demand) | Full SKILL.md, loaded when you invoke a skill | 0 tokens unless used |

### Why this works

```
Session start:   [skill names only]      "variant-calling/gatk-variant-calling"   ~5 tokens
Skill invoked:   [full SKILL.md loaded]   200+ lines of code patterns            ~2,000 tokens
No skills invoked this session: you pay for the index only, never the content.
```

**bioSkills (546 skills across 63 categories):** loading every SKILL.md eagerly would push ~55 MB of content into context. With deferred loading they cost ~0 tokens until invoked.

### How skills load in each harness

All six harnesses receive the same 2,652-skill pool. Codex and Pi symlink to source repos for skills already in valid format; the symlink-vs-copy mix differs per harness based on which sources the install chose to symlink. Codex's 64-char directory-name limit is **defensive only** — no skill in the current corpus exceeds it, so no truncation occurs. See the [What Each Harness Gets](#what-each-harness-gets) table above for per-harness delivery. The key distinction: Claude Code uses **native deferred loading** — the 2,652 skill names cost ~7,500 tokens in the index, while each skill's full content (2,000+ tokens) loads only when that skill is invoked.

### lean-skills.txt (for `claude` CLI + ollama sessions)

Injects a brief summary of your personal learned skills so the model knows they exist:

| File | Size | Tokens | Used for |
|------|------|--------|----------|
| `~/.claude/skills-cache/lean-skills.txt` | ~13 KB | ~3K | Injected via `--append-system-prompt-file` at session start (top 50 learned skills by confidence) |
| `~/.claude/skills-cache/combined-skills.txt` | ~7 MB | ~1.8M | Reference / local search only — never injected |

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
# Full setup: MCP servers + inject skills into Desktop sessions
./scripts/setup-claude-desktop.sh

# MCP servers only (zero token cost — servers idle until invoked)
./scripts/setup-claude-desktop.sh --mcp-only

# Inject skills only (no MCP)
./scripts/setup-claude-desktop.sh --skills-only

# Overwrite existing skills
./scripts/setup-claude-desktop.sh --skills-only --force

# Package .skill files for manual upload (fallback method)
./scripts/setup-claude-desktop.sh --package-skills --tier full
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

**Skills injection** — skills from `~/.claude/skills/` are symlinked into the Desktop's `skills-plugin` directory and registered in `manifest.json`. This makes them appear in both:

- **Customize → Capabilities panel** — after restarting Desktop
- **Agent-mode `/` slash commands** — during coding sessions

### How skill injection works

The `setup-claude-desktop.sh` script:

1. Finds all Desktop session directories under `~/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/`
2. Creates symlinks from each skill in `~/.claude/skills/` into the Desktop's `skills/` directory
3. Updates `manifest.json` to register all injected skills

For bulk import (e.g. after a clean install), you can also use:

```bash
# Close Claude Desktop first, then run:
./scripts/desktop-batch-import.sh             # Import all skills
./scripts/desktop-batch-import.sh --dry-run   # Preview what would be imported
./scripts/desktop-batch-import.sh --force     # Overwrite existing
./scripts/desktop-batch-import.sh --clean     # Remove custom skills first
```

### Manual upload (fallback)

If symlinks don't work (e.g. cross-filesystem), you can package skills as `.skill` files:

```bash
./scripts/build-desktop-skills.sh                   # default: full tier
./scripts/build-desktop-skills.sh --tier standard    # fewer skills
```

Then in Claude Desktop: **Customize** → **Skills** → **+** → **Upload a skill** → select from `configs/desktop-skills/`.

### Token economics (Desktop)

| Component | Token cost |
|-----------|-----------|
| MCP servers | Zero until invoked |
| Skills (symlinked) | Zero — loaded on-demand, no injection overhead |

Skills are symlinked (not copied), so they load on-demand just like in Claude Code CLI — no context window overhead.

### CLI vs Desktop comparison

| Feature | Claude Code CLI | Claude Desktop GUI |
|---------|----------------|-------------------|
| Setup script | `install.sh` | `scripts/setup-claude-desktop.sh` |
| Config file | `~/.claude.json` | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| MCP servers | 9 auto (incl. beads) + manual API-key servers | 6 auto + API-key servers copied from CLI; skillgraph via Settings → Integrations |
| Skills injection | 3,265 files (2,652 unique) via native `/skills` + lean cache (top 50, ~3K tokens) | Symlinked from `~/.claude/skills/` into Desktop sessions — same on-demand loading |
| Prompt caching | `tengu_system_prompt_global_cache: true` | Built-in Project caching |
| Shell wrappers | `_claude_with_skills` in `.bashrc`/`.zshrc` | N/A (GUI app) |

---

## Beads Integration

> **Powered by [beads](https://github.com/gastownhall/beads)** — AI-native cross-session work item tracking. Works with every harness (Claude Code, Codex, Copilot, OpenClaw, Pi) via MCP.

### What beads does

Beads lets you create, track, and share work items across AI coding sessions. Unlike session memory (which is per-harness), beads items persist in your project via `AGENTS.md` — a harness-agnostic file every AI tool reads.

| Command | What it does |
|---------|-------------|
| `bd prime` | Type this as your first message inside Claude — pulls all open work items into context |
| `bd ready` | List items ready to work on |
| `bd create "task"` | Create a new work item |
| `bd update <id> --claim` | Claim a work item (also: `--title`, `--description`, `--notes`) |
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

- `docs/SKILLS-CATALOG.md` — Full per-source skill listing + category breakdown
- `docs/TROUBLESHOOTING.md` — Common problems and solutions
- `~/.claude-everything-claude-code/` — Full ECC skills repository (272 skills)
- `~/.claude-medical-skills/` — OpenClaw-Medical clinical skills (896 skills)
- `~/.claude-operon-skills/` — operon bioinformatics protocols (556 protocols)
- `~/.claude-tooluniverse/` — ToolUniverse drug-discovery skills (150 skills)
- `~/.claude-scientific-skills/` — K-Dense scientific agent skills (147 skills)
- `~/.claude-clawbio-skills/` — ClawBio bioinformatics pipeline skills (90 skills)
- `~/.claude-deepmind-skills/` — Google DeepMind science-skills (37 skills)
- `~/.claude-sciagent-skills/` — SciAgent-Skills (197 skills, 12 categories)
- `~/.claude-bionemo-skills/` — NVIDIA BioNeMo GPU-accelerated bio skills (35 skills)
- `~/.claude-nature-paper-skills/` — Nature-Paper manuscript-workflow skills (18 skills)
- `~/.claude-life-sciences/` — Anthropic life-sciences skills (6 skills)
- `~/.claude-bipartite/` — Bipartite research workflow CLI + skills (37 skills, 16 agents; `bip` binary at `~/go/bin/bip`)
- [GoekeLab/awesome-genomic-skills](https://github.com/GoekeLab/awesome-genomic-skills) — Curated list of genomic/bioinformatics agent skills + MCP servers
- [variomeanalytics/bioinformatics-agent-skills](https://github.com/variomeanalytics/bioinformatics-agent-skills) — Bioinformatics pipeline skills + knowledge graph (MCP)
- `~/.claude-everything-claude-code/mcp-configs/mcp-servers.json` — Complete MCP server reference
