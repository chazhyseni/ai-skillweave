# Skill sources

Fresh installs select ECC; existing source choices persist. Keep all libraries
needed for your work available. Skill bodies are read on demand, but their
catalog metadata still consumes context—see the
[cost and caching distinctions](../README.md#token-cost-and-automatic-selection).
Counts change with upstream revisions, selection and name collisions; there is
no fixed cross-harness skill total. No visibility filter is imposed by Skillweave.

## Available sources

| Source ID | Upstream | Focus |
|---|---|---|
| `ecc` | [ECC](https://github.com/affaan-m/ECC) | Software engineering, testing, architecture, security |
| `science` | [K-Dense](https://github.com/K-Dense-AI/scientific-agent-skills) | Scientific computing, databases, research workflows |
| `bio` | [ClawBio](https://github.com/ClawBio/ClawBio) | Bioinformatics workflows with supporting scripts |
| `bioskills` | [bioSkills](https://github.com/GPTomics/bioSkills) | Bioinformatics reference collection; **archived upstream** |
| `medical` | [OpenClaw-Medical](https://github.com/FreedomIntelligence/OpenClaw-Medical-Skills) | Aggregated clinical and life-science workflows |
| `operon` | [operon](https://github.com/swaruplab/operon) | Bioinformatics protocols |
| `tooluniverse` | [ToolUniverse](https://github.com/mims-harvard/ToolUniverse) | Drug discovery and scientific tools |
| `sciagent` | [SciAgent](https://github.com/jaechang-hits/SciAgent-Skills) | Scientific analysis and research |
| `deepmind` | [science-skills](https://github.com/google-deepmind/science-skills) | Scientific database and model workflows |
| `bionemo` | [BioNeMo toolkit](https://github.com/NVIDIA-BioNeMo/bionemo-agent-toolkit) | NVIDIA life-science models and services |
| `nature-paper` | [Nature-Paper](https://github.com/Boom5426/Nature-Paper-Skills) | Manuscript preparation and review |
| `bipartite` | [Bipartite](https://github.com/matsen/bipartite) | Literature, manuscripts and research coordination |
| `anthropic` | [Anthropic skills](https://github.com/anthropics/skills) | Official reference skills |
| `life-sciences` | [Anthropic life-sciences](https://github.com/anthropics/life-sciences) | Life-science workflows |
| `codex-curated` | [OpenAI skills](https://github.com/openai/skills) | Codex skill collection |
| `huggingface` | [Hugging Face skills](https://github.com/huggingface/skills) | Focused local-model, memory, evaluation and dataset skills |

ECC's previous `affaan-m/everything-claude-code` URL redirects to `affaan-m/ECC`.
bioSkills stopped maintenance in August 2026; treat it as a reference snapshot,
not a source of ongoing fixes.

### Upstream audit — 2026-09-25

Default-branch revisions below were checked through the GitHub repository and
commit APIs. Dates are commit dates, not repository activity timestamps.
The audited machine had ten tracked sources at different revisions, one matching
source, four legacy snapshots without Git history, and no Hugging Face checkout.
A different revision is an update candidate, not proof that local edits may be
discarded. These are audit observations, not installation pins.

| Source | Remote revision | Commit date (UTC) | Audited local state |
|---|---|---|---|
| ECC | `e482e579415f` | 2026-09-24 | Different revision |
| K-Dense | `49c6e97775ea` | 2026-09-21 | Legacy snapshot |
| ClawBio | `b360efaf46fd` | 2026-09-25 | Legacy snapshot |
| bioSkills | `d91ed3d56301` | 2026-08-15 | Different revision; archived |
| OpenClaw-Medical | `b1f9b6e3306f` | 2026-07-21 | Different revision |
| operon | `77f5361af5a2` | 2026-09-07 | Different revision |
| ToolUniverse | `78883724c46a` | 2026-09-24 | Different revision |
| SciAgent | `fe505cae14d2` | 2026-08-29 | Different revision |
| DeepMind | `68832757cbbf` | 2026-09-14 | Different revision |
| BioNeMo | `061bec95a9a1` | 2026-09-22 | Different revision |
| Nature-Paper | `c734748f1b63` | 2026-09-25 | Different revision |
| Bipartite | `73636d221359` | 2026-09-25 | Different revision |
| Anthropic | `33375500bcea` | 2026-09-24 | Legacy snapshot |
| Anthropic life-sciences | `e96556b637b5` | 2026-05-08 | Matches remote |
| OpenAI | `49f948faa925` | 2026-06-24 | Legacy snapshot |
| Hugging Face | `80f9fa530e46` | 2026-09-24 | Not installed |

Resolve a listed revision through its linked upstream above, or query
`https://api.github.com/repos/OWNER/REPO/commits/BRANCH`. Check archived status
at `https://api.github.com/repos/OWNER/REPO`; for example
[bioSkills metadata](https://api.github.com/repos/GPTomics/bioSkills).
Run `--check` on the destination machine before applying updates. Source
checkouts and installed libraries on the audited user's live HOME were not
reset or mass-reinstalled as part of this repository audit.

The related [Hugging Face skill catalog](https://github.com/huggingface/skills/tree/main/skills)
was checked against the five selected skill IDs. The newer
[`huggingface-best`](https://github.com/huggingface/skills/tree/main/skills/huggingface-best)
is relevant for benchmark discovery, but is not auto-selected: its parameter-only
memory estimates omit runtime overhead, and its examples assume a cached HF
token. Prefer `huggingface-local-models`, `hf-mem` and independent measurements
for subscription-free local model selection.


## Select and update

```bash
bash scripts/update-ecc.sh --list-sources
bash scripts/update-ecc.sh --with-science --with-bio --with-curated
bash scripts/update-ecc.sh --with-source deepmind --with-source tooluniverse
bash scripts/update-ecc.sh --without-source medical
bash scripts/update-ecc.sh --check
```

`--with-curated` selects Anthropic and OpenAI. The installer also accepts paired
`--with-`/`--without-` flags for science, bio, bioskills and huggingface. Choices
persist; source checkouts are not deleted when disabled.

`--with-huggingface` installs `hf-cli`, `hf-mem`, `huggingface-local-models`,
`huggingface-community-evals`, and `huggingface-datasets`, not its AWS/cloud
training collection. [Microsoft skills](https://github.com/microsoft/skills)
are useful selectively for Azure/Foundry projects, but are not bundled here.

## Delivery and dependencies

The synchronizer selects maintained skill roots rather than whole-repository
plugin mirrors. Duplicate **declared names** (`SKILL.md` frontmatter), even under
different directory names, use source priority, with personal learned skills
highest; collisions are reported during sync. This matches native OMP identity.
Supporting files travel with each skill. Unmanaged local skills are not
automatically exported to other harnesses.

Installing instructions does **not** install their tools or certify their
results. Skills can require credentials, datasets, R/Python packages, GPUs,
external APIs or separately installed CLIs such as `bip`. ECC/Bipartite agents
and commands are not installed by the native skill synchronizer.

Review each upstream license and executable resource before use, especially
aggregated medical collections. Scientific and clinical claims require
independent validation. See the [README](../README.md#native-harness-paths) for
native paths and [troubleshooting](TROUBLESHOOTING.md) for update conflicts.
