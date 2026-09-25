# Skill sources

Fresh installs select ECC. Add only the libraries useful for your work: large
skill indexes consume context, and harnesses may omit entries when budgets are
exceeded. Counts change with upstream revisions, selection and name collisions;
there is no fixed cross-harness skill total.

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
plugin mirrors. Duplicate directory names use source priority, with personal
learned skills highest; collisions are reported during sync. Supporting files
travel with each skill. Unmanaged local skills are not automatically exported
to other harnesses.

Installing instructions does **not** install their tools or certify their
results. Skills can require credentials, datasets, R/Python packages, GPUs,
external APIs or separately installed CLIs such as `bip`. ECC/Bipartite agents
and commands are not installed by the native skill synchronizer.

Review each upstream license and executable resource before use, especially
aggregated medical collections. Scientific and clinical claims require
independent validation. See the [README](../README.md#native-harness-paths) for
native paths and [troubleshooting](TROUBLESHOOTING.md) for update conflicts.
