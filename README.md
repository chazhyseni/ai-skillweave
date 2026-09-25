# ai-skillweave

Manage portable Agent Skills across **Claude Code, Codex, OpenClaw, Pi, Copilot
CLI, Hermes, and oh-my-pi**. Update selected upstream libraries and personal
skills through one ownership-aware synchronizer.

**No Ollama subscription required.** Skill delivery works independently of model
hosting. Local Ollama and llama.cpp are optional; existing model settings stay
unchanged unless you explicitly configure them.

[Skill sources](docs/SKILLS-CATALOG.md) · [Local models](docs/LOCAL-MODELS.md) ·
[Troubleshooting](docs/TROUBLESHOOTING.md)

## Install

Requires Bash, Git, and Python with `venv`/pip on macOS, Linux, or WSL. Python
3.12 or 3.13 is recommended, especially for optional learning dependencies.
Core dependencies use `~/.claude/skillweave-venv`, not your system Python.
Install your chosen harnesses separately; this installer does not install
system/global packages, harness binaries, model weights, or subscriptions.

```bash
git clone https://github.com/chazhyseni/ai-skillweave
cd ai-skillweave

# Start with skills only; fresh installs select ECC.
bash install.sh --only skills

# Optional scientific, official, and local-model skill libraries.
bash install.sh --only skills --with-science --with-bio --with-curated --with-huggingface
```

Source choices persist. Existing recognized checkouts remain enabled unless
explicitly disabled. bioSkills is available with `--with-bioskills`, but its
upstream is archived. See the [source guide](docs/SKILLS-CATALOG.md).

Bare `bash install.sh` also configures harnesses already on `PATH`. To target
one installed harness, use `--only claude|codex|openclaw|pi|copilot|hermes|omp`;
this propagates existing sources offline without installing unrelated tools.
Open a new Bash/Zsh shell afterward to load the helper aliases.

| Option | Behavior |
|---|---|
| `--skip-skills` | Skip skill delivery and shell integration |
| `--offline` | No source fetches; initial Python dependency setup may still need network |
| `--learn` | Opt in to learning dependencies and extraction; requires the skills layer |
| `--no-learn` | Skip learning setup/extraction (default) |
| `--verify` | Read-only diagnostics |
| `--uninstall` | Remove unchanged managed skills and shell blocks; preserve user data, source clones, environments and harness configs |

Use `bash install.sh --help` for all options. Harness runtime requirements vary:
current OpenClaw requires Node `>=24.16.0 <25` or `>=26.1.0`; Claude Code's npm
package requires Node 22+; OMP requires Bun 1.3.14+. Pi's maintained package is
`@earendil-works/pi-coding-agent`, replacing `@mariozechner/pi-coding-agent`.
Check each project's installation instructions before upgrading.

## Update and sync

```bash
bash scripts/update-ecc.sh --list-sources       # IDs, paths, selections
bash scripts/update-ecc.sh --check              # read-only remote check + preview
bash scripts/update-ecc.sh                      # update every enabled source
bash scripts/update-ecc.sh --offline            # reconcile local content only
bash scripts/update-ecc.sh --offline --dry-run   # preview without writing
bash scripts/update-ecc.sh --with-source deepmind --with-source tooluniverse
bash scripts/update-ecc.sh --without-bioskills   # persistently disable a source
```

Despite its historical name, `update-ecc.sh` updates **all enabled sources**.
Unchanged ECC content does not prevent other sources from updating.

- Source updates require clean checkouts and fast-forward merges; no forced resets.
- Full skill directories propagate, including scripts, assets and executable modes.
- Content fingerprints govern updates and pruning—not modification times.
- Personal files, unmanaged skills and edited managed files are preserved.
  Conflicts return nonzero with guidance; `--no-prune` postpones removals.
- Failed/missing sources retain their previously delivered skills. Explicit
  source opt-outs remove only unchanged managed output.

Ownership and source selections are stored under `~/.claude/skills-cache/`.
Old copied repositories without `.git` need a deliberate backup/reclone to
update; `--offline` can continue delivering their existing snapshots. Old
name-only manifests cannot prove ownership, so migration preserves conflicts.

## Native harness paths

| Harness | Skill directory |
|---|---|
| Claude Code | `~/.claude/skills` |
| Codex | `~/.agents/skills` |
| OpenClaw | `~/.openclaw/workspace/skills` |
| Pi | `~/.pi/agent/skills` |
| Copilot CLI | `~/.copilot/skills` |
| Hermes | `~/.hermes/skills/ai-skillweave` |
| oh-my-pi | `~/.omp/agent/skills`, plus existing profile agent directories |

Ordinary sync uses existing harness directories; `--harness NAME` explicitly
selects/creates a destination. `SKILLWEAVE_OMP_AGENT_DIR` selects a custom OMP
agent directory. OMP is separate from Pi; current Codex uses `.agents/skills`,
not the old `.codex/skills` path. Custom workspaces must match the delivery path.

Restart/reload your harness after syncing and inspect its skill list.
**Installed is not necessarily advertised or invoked:** discovery settings,
disabled skills, duplicate sources and model context budgets still apply.
`combined-skills.txt` is a local reference cache, never a system prompt.

## Local inference

```bash
# Explicit model setup; does not start the server or download weights.
bash install.sh --only pi --backend ollama --model qwen3.5:4b

# Use an existing llama-server alias and endpoint.
bash install.sh --only omp --backend llama.cpp --model local-agent \
  --base-url http://127.0.0.1:8080/v1 --context 16384 --max-tokens 4096
```

Model setup supports Pi, OMP, OpenClaw and current Codex. Ollama launch mappings
are Ollama-only. Claude/Copilot skill delivery does not configure their provider
APIs. See [model selection, sizing and server setup](docs/LOCAL-MODELS.md).

## Optional learning

```bash
bash install.sh --only skills --learn --no-llm
bash sync-learned-skills.sh --llm-backend ollama --llm-model qwen3.5:4b
bash sync-learned-skills.sh --sync-only   # no extraction or source fetch
bash sync-learned-skills.sh --dry-run
bash sync-learned-skills.sh --stats
bash sync-learned-skills.sh --prune       # archive low-signal input, sync removals
```

Review histories before processing sensitive data. Extraction groups recurring
corrections and writes personal skills under `~/.claude/skills/learned/`.
No-LLM mode only retains complete repeated conditional rules
(`When/If <context>, <instruction>.`); underspecified groups can yield zero skills.
LLM mode uses one explicit backend, with no automatic cloud fallback.

Aliases: `learn-sync`, `learn-sync-dry`, `learn-stats`, `learn-prune`,
`skills-update`. Installed helpers live under `~/.claude/scripts/`.
Claude learning hooks are opt-in; `--no-learn` does not remove older hooks.

## Integrations and checks

MCP setup preserves existing entries, skips missing local servers, and does not
automatically enable remote endpoint templates. Local inference does not make
remote MCP tools offline or credential-free. Beads setup is explicit
(`--only beads`), not required for skills.

Claude Desktop exports are separate snapshots: rebuild and re-import them after
source changes. Personal instruction bundles and internal reports are not shipped.

```bash
bash install.sh --verify
python3 -B -m unittest discover -s tests -v
```

Tests use temporary homes and local Git remotes. They cover propagation,
pruning, user-edit preservation, read-only checks, source selection and no-LLM
extraction. Diagnostics check files/configuration—not credentialed agent sessions
or the correctness of upstream scientific instructions.
