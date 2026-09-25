# ai-skillweave

Manage portable Agent Skills across **Claude Code, Codex, OpenClaw, Pi, Copilot
CLI, Hermes, and oh-my-pi**. Update selected upstream libraries and personal
skills through one ownership-aware synchronizer. Optionally learn from corrections
and session history, configure local models, and set up MCP integrations or Ruflo.

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
| `--repair-sources` | Clone upstream first, then back up and replace legacy/dirty source trees |
| `--repair-conflicts` | Back up differing destination skills before replacing them |
| `--with-ruflo` | Also install/reuse the opt-in Ruflo CLI; no project initialization or MCP registration |
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

# Repair legacy OMP copies safely (preview first; keeps full backups).
bash scripts/setup-omp-skills.sh --repair-conflicts --dry-run
bash scripts/setup-omp-skills.sh --repair-conflicts
# Test the actual OMP loader, not just copied-file counts.
bash scripts/verify-omp.sh
bash scripts/update-ecc.sh --without-bioskills   # persistently disable a source
```

Despite its historical name, `update-ecc.sh` updates **all enabled sources**.
Unchanged ECC content does not prevent other sources from updating.

Normal installation uses valid copied/locally modified sources without treating
their Git state as an installation error. It reports skipped upstream refreshes;
clean tracked sources still update. To migrate those sources explicitly:

```bash
bash scripts/update-ecc.sh --repair-sources --repair-conflicts --dry-run
bash install.sh --only skills --repair-sources --repair-conflicts
```

The complete original sources remain in printed `skillweave-source-backups`
locations; custom edits are not automatically merged into the new upstream
copies. See [recovery and pip-index guidance](docs/TROUBLESHOOTING.md).

- In-place source updates require clean checkouts and fast-forward merges; no forced resets.
- Full skill directories propagate, including scripts, assets and executable modes.
- Identity and source priority use the declared `name` in `SKILL.md`, as OMP does,
  not upstream folder names. This prevents duplicate-name shadowing.
- Content fingerprints govern updates and pruning—not modification times.
- Identical legacy copies are adopted; missing supporting files are filled in.
- Personal files, unmanaged skills and edited managed files are preserved by
  default. A conflicting asset blocks updates to its entire skill, preventing
  new instructions from being paired with stale scripts.
- `--repair-conflicts` explicitly backs up differing copies and legacy aliases
  outside discovery before replacement. Personal additions remain in the backup,
  not in the replacement skill. Backups are never automatically deleted.
- Conflicts return nonzero; per-harness counts distinguish ownership records
  from successful delivery. `--no-prune` postpones ordinary removals.
- Failed/missing sources retain their previously delivered skills. Explicit
  source opt-outs remove only unchanged managed output.

Ownership and source selections are stored under `~/.claude/skills-cache/`.
Old copied repositories without `.git` need a deliberate backup/reclone to
update; `--offline` can continue delivering their existing snapshots. Old
name-only manifests cannot prove ownership; differing copies need the explicit
backup-and-replace recovery above.

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
agent directory. `OMP_PROFILE` (or legacy `PI_PROFILE`), `PI_CONFIG_DIR`, and
`PI_CODING_AGENT_DIR` are also honored; a named OMP profile takes precedence over
the shared agent-dir variable. The Skillweave-specific override is strongest.
OMP is separate from Pi; current Codex uses `.agents/skills`,
not the old `.codex/skills` path. Custom workspaces must match the delivery path.

Restart/reload your harness after syncing and inspect its skill list.
**Installed is not necessarily advertised or invoked:** discovery settings,
disabled skills, duplicate sources and model context budgets still apply.
`bash scripts/verify-omp.sh` checks every native skill's content through
`omp read skill://NAME:raw`, reporting duplicate names, disabled skills,
missing discovery and shadowing. Run it from the project you intend to use.
It makes no model requests; OMP may initialize its own settings/cache.
`combined-skills.txt` is a local reference cache, never a system prompt.

### Token cost and automatic selection

Skills are **not free context**. OMP advertises enabled names/descriptions, then
the model reads relevant bodies on demand through `skill://`. Relevance is
model-driven, not a guaranteed query classifier. Installing skills does not
automatically execute their scripts.

**Full-library availability remains the default.** Skillweave does not add a
visibility allowlist, hide skills, or inject the combined library into prompts.
Keep all the skills you need installed and let the model select relevant bodies.

Catalog metadata occupies context even when skill bodies are loaded on demand.
Prompt caching may reduce repeated input costs, but does not remove that context.

If a particular model cannot accommodate the full catalog, the following is an
**optional** session restriction—not an installation requirement:

```bash
omp --skills 'python-*,verification-loop'
```

An optional persistent project restriction uses `.omp/config.yml`:

```yaml
skills:
  includeSkills:
    - python-*
    - verification-loop
```

An empty allowlist means **all**, not none. Excluded skills are not available in
that session: change the filter when changing tasks. `hide: true` keeps a skill
manually reachable while removing its advertised description, but the model
then lacks that routing hint. Do not edit managed copies to set it: updates
correctly treat those edits as conflicts.

## Local inference

```bash
# Explicit model setup; does not start the server or download weights.
bash install.sh --only pi --backend ollama --model qwen3.5:4b --context 65536

# Use an existing llama-server alias and endpoint.
bash install.sh --only omp --backend llama.cpp --model local-agent \
  --base-url http://127.0.0.1:8080/v1 --context 65536 --max-tokens 4096
```

64K is a full-library sizing example, not a measured hardware-fit guarantee.
Configure the server to match; budget for tools, history and output as well as
the catalog. These commands do not silently resize a running server.

Model setup supports Pi, OMP, OpenClaw and current Codex. Ollama launch mappings
are Ollama-only. Claude/Copilot skill delivery does not configure their provider
APIs. See [model selection, sizing and server setup](docs/LOCAL-MODELS.md).

### Next step: litMoE

[litMoE](https://github.com/chazhyseni/litMoE) provides a local-model gateway
with OpenAI- and Anthropic-compatible APIs, routing named models to llama.cpp
or ktransformers. It adds hardware-aware model selection and engine lifecycle
management; it is not itself an inference engine. Its
[harness guide](https://github.com/chazhyseni/litMoE/blob/main/docs/HARNESSES.md)
covers isolated Claude and Hermes launchers that leave normal provider settings
unchanged. Skillweave supplies the skills; litMoE can supply the model-serving
layer. Installation and model downloads remain separate and explicit.

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
OMP histories are included: the default agent, existing profiles, or the active
profile/custom agent directory. To process only OMP, use
`python3 extract-conversation-skills.py --harness omp --no-llm`.
No-LLM mode only retains complete repeated conditional rules
(`When/If <context>, <instruction>.`); underspecified groups can yield zero skills.
LLM mode uses one explicit backend, with no automatic cloud fallback.

Aliases: `learn-sync`, `learn-sync-dry`, `learn-stats`, `learn-prune`,
`skills-update`. Installed helpers live under `~/.claude/scripts/`.
Claude learning hooks are opt-in; `--no-learn` does not remove older hooks.

### Claude hooks

`bash scripts/setup-hooks.sh` installs the search hooks. Opt in to local prompt
capture with `bash scripts/setup-learning-hook.sh` (also enabled by the main
installer's `--learn` path when Claude is selected).

| Event | Behavior |
|---|---|
| `PreToolUse` (`Glob\|Grep`) | One reminder before broad searches in a Codesight-indexed project with a registered Codesight server |
| `PostToolUse` (Codesight summary) | Suppress that reminder after a successful summary |
| `UserPromptSubmit` (opt-in) | Save candidate corrections/preferences locally without echoing them into model context |
| `SessionEnd` | Remove that session's search-reminder state |

Hooks use Python's standard library: no inference, model downloads, or network
requests. Codesight registration is not a health check; if the server is
unavailable, retrying the search proceeds. Capture records live under
`~/.claude/skills/learned/events/` with private file permissions. The normal
learning pipeline reads them alongside history, deduplicates by session, and
applies its existing evidence gates. A captured prompt is **not** automatically
a trusted skill; session exit does not run extraction.

Setup upgrades recognized managed hook copies, migrates repository-path
registrations to installed copies, and preserves custom files and unrelated
hooks. Claude's hook protocol is not installed into other harnesses; their
session-history extraction remains separate. See the
[Claude hook reference](https://code.claude.com/docs/en/hooks).

## Integrations and checks

MCP setup preserves existing entries, skips missing local servers, and does not
automatically enable remote endpoint templates. Local inference does not make
remote MCP tools offline or credential-free. Beads setup is explicit
(`--only beads`), not required for skills.

### Optional Ruflo

```bash
bash install.sh --only ruflo       # Ruflo only; no skill sync or Python setup
bash install.sh --with-ruflo       # Normal installation plus Ruflo
bash install.sh --only ruflo --offline  # Reuse an existing installation, no npm download
```

An existing `ruflo` executable is preserved. Otherwise this installs the pinned
`ruflo@3.45.0` and `@claude-flow/cli@3.45.0` packages under
`~/.local/share/ai-skillweave/ruflo`, with a lockfile and a launcher in
`~/.local/bin` if that path is free. Requires Node >=20 and npm; native optional
dependencies may have additional platform/build requirements. No sudo or global
npm install is used, and your project's package files are not changed.

Add `~/.local/bin` to PATH if needed, then use `ruflo --version`.
Project initialization is a separate decision: review `ruflo init --help` in the
project you intend to configure. Skillweave does **not** run `init`, `doctor
--fix`, start a daemon, register Ruflo MCP tools, or add its skill catalog.
Installing the CLI therefore does not automatically increase harness prompt size
or invoke a model. Existing Beads/harness targets still require their binaries
to be installed separately. Skills uninstall leaves the optional Ruflo CLI intact.

See [Ruflo upstream](https://github.com/ruvnet/ruflo) and its
[published package requirements](https://registry.npmjs.org/ruflo/3.45.0).

### Diagnostics

Claude Desktop exports are separate snapshots: rebuild and re-import them after
source changes. Personal instruction bundles and internal reports are not shipped.

```bash
bash install.sh --verify
"$HOME/.claude/skillweave-venv/bin/python" -B -m unittest discover -s tests -v
```

Tests use temporary homes and local Git remotes. They cover propagation,
pruning, user-edit preservation, legacy adoption, backup recovery, duplicate
declared names, profile selection, read-only checks and no-LLM extraction.
`--verify` checks files/configuration; `scripts/verify-omp.sh` additionally uses
the installed native OMP loader. Neither certifies upstream scientific instructions.
