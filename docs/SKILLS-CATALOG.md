# Skills Catalog

Overview of all skills available through ai-skillweave, organized by source and category.

**Total: 2,652 unique skills** delivered to all 6 harnesses — `update-ecc.sh` merges every source repo into 2,652 unique skill directories. Per-harness on-disk SKILL.md file counts run higher (Claude 3,265 · OpenClaw 3,310 · Codex 3,318 · Pi 3,345 · Copilot 3,265) because each harness also carries its own native skills, the learned-skills cache, and source-repo duplicates that the unique count collapses. Each source's **on-disk** size and its **net-new** (deduplicated) contribution to the 2,652:

| Source | On-disk | Net-new | Provenance |
|---|---:|---:|---|
| OpenClaw-Medical | 896 | 708 | [FreedomIntelligence/OpenClaw-Medical-Skills](https://github.com/FreedomIntelligence/OpenClaw-Medical-Skills) → `~/.claude-medical-skills/skills/` |
| operon | 556 | 389 | [swaruplab/operon](https://github.com/swaruplab/operon) → `~/.claude-operon-skills/protocols/` |
| bioSkills | 546 | 514 | [GPTomics/bioSkills](https://github.com/GPTomics/bioSkills) → `~/.claude/skills/` at depth-3 (63 categories) |
| ECC | 272 | 272 | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) → `~/.claude-everything-claude-code/skills/` (+ 92 commands + 67 agents, Claude-only) |
| SciAgent | 197 | 136 | [jaechang-hits/SciAgent-Skills](https://github.com/jaechang-hits/SciAgent-Skills) → `~/.claude-sciagent-skills/skills/` (12 categories) |
| ToolUniverse | 150 | 150 | [mims-harvard/ToolUniverse](https://github.com/mims-harvard/ToolUniverse) → `~/.claude-tooluniverse/skills/` |
| K-Dense | 147 | 146 | [K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills) → `~/.claude-scientific-skills/scientific-skills/` (107 tagged `skill-author: K-Dense Inc.`) |
| ClawBio | 90 | 90 | [ClawBio/ClawBio](https://github.com/ClawBio/ClawBio) → `~/.claude-clawbio-skills/skills/` (executable Python scripts) |
| DeepMind | 37 | 37 | [google-deepmind/science-skills](https://github.com/google-deepmind/science-skills) → `~/.claude-deepmind-skills/skills/` |
| Bipartite | 37 | 37 | [matsen/bipartite](https://github.com/matsen/bipartite) → `~/.claude-bipartite/skills/` (+ 16 subagent definitions) |
| BioNeMo | 35 | 33 | [NVIDIA-BioNeMo/bionemo-agent-toolkit](https://github.com/NVIDIA-BioNeMo/bionemo-agent-toolkit) → `~/.claude-bionemo-skills/` |
| Nature-Paper | 18 | 17 | [Boom5426/Nature-Paper-Skills](https://github.com/Boom5426/Nature-Paper-Skills) → `~/.claude-nature-paper-skills/skills/` (MIT) |
| Anthropic | 17 | 13 | [anthropics/skills](https://github.com/anthropics/skills) → `~/.claude-curated-skills/anthropic-official/skills/` |
| life-sciences | 6 | 5 | [anthropics/life-sciences](https://github.com/anthropics/life-sciences) → `~/.claude-life-sciences/` |
| OpenAI Codex curated | 44 | 0 | [openai/skills](https://github.com/openai/skills) → `~/.claude-curated-skills/openai-codex/skills/` (under `.curated/` + `.system/`; overlap ECC and ship natively with the Codex harness, so 0 net-new) |
| claude_extras | — | 105 | Imported into `~/.claude/skills/` with no live upstream repo; collected by the `claude_extras` supplemental scan in `update-ecc.sh` |
| Personal learned | grows | — | `learned/events/`, distilled via `extract-conversation-skills.py`; 33 archived in `learned/.archive/` |

**Per-harness file counts** (on-disk SKILL.md resolved through symlinks — higher than the 2,652 unique total because each harness also carries native skills, the learned cache, and duplicates):

- **Claude: 3,265** — full library, native deferred loading via `/skills`.
- **OpenClaw: 3,310** — real file copies.
- **Codex: 3,318** — real copies + symlinks to source repos + Codex-native skills. 0 broken symlinks.
- **Pi: 3,345** — 61 curated real copies + symlinks to source repos. 0 broken symlinks.
- **Copilot: 3,265** — symlinked to `~/.claude/skills/`, so it mirrors Claude.
- **Hermes: 3,675** — real copies into `~/.hermes/skills/ai-skillweave/` (the 2,652 pool); native toolsets + the openclaw-imports staging set untouched.

What's structural: **2,652 unique skills** flow to all 6 harnesses, drawn from 15 source repos — OpenClaw-Medical, operon, bioSkills, ECC, SciAgent, ToolUniverse, K-Dense, ClawBio, DeepMind, Bipartite, BioNeMo, Nature-Paper, Anthropic, life-sciences, and OpenAI Codex curated — plus 105 imported `claude_extras` and the personal learned skills. See the README's "What Each Harness Gets" table for per-harness delivery details.

---

## Everything Claude Code (ECC) — 272 skills

From [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code). Production-ready agent skills covering every domain of software development.

### Software Architecture & Design
- `architecture-decision-records`, `hexagonal-architecture`, `backend-patterns`, `frontend-patterns`, `api-design`, `design-system`, `frontend-design`, `frontend-slides`, `product-capability`, `product-lens`, `blueprint`, `liquid-glass-design`

### Language-Specific Patterns & Testing
- **Python**: `python-patterns`, `python-testing`, `django-patterns`, `django-security`, `django-tdd`, `django-verification`, `pytorch-patterns`
- **TypeScript/JS**: `frontend-patterns`, `nestjs-patterns`, `nextjs-turbopack`, `bun-runtime`, `nuxt4-patterns`, `nodejs-keccak256`
- **Kotlin/Android**: `kotlin-patterns`, `kotlin-testing`, `kotlin-coroutines-flows`, `kotlin-exposed-patterns`, `kotlin-ktor-patterns`, `android-clean-architecture`, `compose-multiplatform-patterns`, `dart-flutter-patterns`
- **Swift/iOS**: `swiftui-patterns`, `swift-concurrency-6-2`, `swift-actor-persistence`, `swift-protocol-di-testing`
- **Go**: `golang-patterns`, `golang-testing`
- **Rust**: `rust-patterns`, `rust-testing`
- **C++**: `cpp-coding-standards`, `cpp-testing`
- **C#/.NET**: `dotnet-patterns`, `csharp-testing`
- **Java/Spring**: `springboot-patterns`, `springboot-security`, `springboot-tdd`, `springboot-verification`, `jpa-patterns`
- **Perl**: `perl-patterns`, `perl-security`, `perl-testing`
- **PHP/Laravel**: `laravel-patterns`, `laravel-security`, `laravel-tdd`, `laravel-verification`, `laravel-plugin-discovery`
- **Flutter/Dart**: `flutter-dart-code-review`

### Infrastructure & DevOps
- `docker-patterns`, `deployment-patterns`, `database-migrations`, `postgres-patterns`, `clickhouse-io`, `canary-watch`, `continuous-agent-loop`, `autonomous-loops`

### Security & Compliance
- `security-review`, `security-scan`, `safety-guard`, `defi-amm-security`, `llm-trading-agent-security`, `hipaa-compliance`, `healthcare-phi-compliance`, `healthcare-cdss-patterns`, `healthcare-emr-patterns`, `healthcare-eval-harness`, `skill-comply`, `security-bounty-hunter`

### AI & Agent Engineering
- `agentic-engineering`, `ai-first-engineering`, `ai-regression-testing`, `autonomous-agent-harness`, `agent-harness-construction`, `agent-eval`, `agent-introspection-debugging`, `agent-sort`, `agent-payment-x402`, `nanoclaw-repl`, `claude-devfleet`, `claude-api`, `mcp-server-patterns`, `continuous-learning`, `continuous-learning-v2`, `council`, `consciousness-council`

### Content & Media
- `article-writing`, `brand-voice`, `content-engine`, `deep-research`, `documentation-lookup`, `exa-search`, `investor-materials`, `investor-outreach`, `market-research`, `video-editing`, `manim-video`, `remotion-video-creation`, `fal-ai-media`, `videodb`, `crosspost`, `x-api`, `seo`, `social-graph-ranker`

### Data & Research
- `data-scraper-agent`, `iterative-retrieval`, `regex-vs-llm-structured-text`, `repo-scan`, `research-ops`, `knowledge-ops`, `connections-optimizer`, `context-budget`, `token-budget-advisor`, `cost-aware-llm-pipeline`, `benchmark`, `eval-harness`, `prompt-optimizer`

### Quality & Verification
- `tdd-workflow`, `e2e-testing`, `verification-loop`, `coding-standards`, `code-tour`, `codebase-onboarding`, `plankton-code-quality`, `search-first`, `gateguard`

### Domain-Specific
- **Healthcare**: `healthcare-cdss-patterns`, `healthcare-emr-patterns`, `healthcare-phi-compliance`, `healthcare-eval-harness`
- **Finance**: `finance-billing-ops`, `customer-billing-ops`, `evm-token-decimals`, `energy-procurement`
- **Logistics**: `logistics-exception-management`, `returns-reverse-logistics`, `inventory-demand-planning`, `production-scheduling`, `quality-nonconformance`
- **Enterprise ops**: `email-ops`, `google-workspace-ops`, `messages-ops`, `unified-notifications-ops`, `terminal-ops`, `github-ops`, `jira-integration`, `enterprise-agent-ops`, `project-flow-ops`
- **Trade**: `customs-trade-compliance`, `visa-doc-translate`
- **Sales/CRM**: `carrier-relationship-management`, `lead-intelligence`
- **Scientific**: `foundation-models-on-device`

### Other
- `accessibility`, `browser-qa`, `click-path-audit`, `workspace-surface-audit`, `automation-audit-ops`, `ecc-tools-cost-audit`, `configure-ecc`, `dmux-workflows`, `hookify-rules`, `git-workflow`, `santa-method`, `strategic-compact`, `team-builder`, `ui-demo`, `dashboard-builder`, `api-connector-builder`, `content-hash-cache-pattern`, `nutrient-document-processing`, `openclaw-persona-forge`, `opensource-pipeline`, `ralphinho-rfc-pipeline`

---

## ECC Commands — 92 commands

Slash-command skills invoked with `/command` in Claude Code. From [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) `commands/` directory.

### Development Workflows
- `feature-dev`, `code-review`, `review-pr`, `tdd`, `e2e`, `build-fix`, `plan`, `checkpoint`, `refactor-clean`, `verify`, `eval`, `docs`, `update-docs`

### Language-Specific Build/Test/Review
- **Python**: `python-review`
- **Go**: `go-build`, `go-review`, `go-test`
- **Rust**: `rust-build`, `rust-review`, `rust-test`
- **C++**: `cpp-build`, `cpp-review`, `cpp-test`
- **Kotlin**: `kotlin-build`, `kotlin-review`, `kotlin-test`
- **Flutter/Dart**: `flutter-build`, `flutter-review`, `flutter-test`
- **GAN**: `gan-build`, `gan-design`
- **Gradle**: `gradle-build`

### Agent Orchestration
- `orchestrate`, `multi-execute`, `multi-plan`, `multi-workflow`, `multi-frontend`, `multi-backend`, `santa-loop`, `aside`, `sessions`, `save-session`, `resume-session`

### Skill Management
- `skill-create`, `evolve`, `learn`, `learn-eval`, `skill-health`, `promote`, `prune`

### Infrastructure & Quality
- `setup-pm`, `pm2`, `projects`, `devfleet`, `agent-sort`, `claw`, `harness-audit`, `loop-start`, `loop-status`, `quality-gate`, `test-coverage`, `context-budget`, `model-route`, `prompt-optimize`, `rules-distill`, `update-codemaps`

### Hooks
- `hookify`, `hookify-help`, `hookify-configure`, `hookify-list`

### Instincts
- `instinct-import`, `instinct-export`, `instinct-status`

### PRP (Prompt-Refined Pipeline)
- `prp-prd`, `prp-plan`, `prp-implement`, `prp-pr`, `prp-commit`

### Other
- `jira`, `docs`

---

## ECC Agents — 67 agents

Specialized AI agents for focused review, build, and planning tasks. From [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) `agents/` directory.

### Code Review
- `code-reviewer`, `typescript-reviewer`, `python-reviewer`, `cpp-reviewer`, `csharp-reviewer`, `go-reviewer`, `java-reviewer`, `kotlin-reviewer`, `rust-reviewer`, `dart-build-resolver`, `flutter-reviewer`

### Build & Error Resolution
- `build-error-resolver`, `cpp-build-resolver`, `go-build-resolver`, `java-build-resolver`, `kotlin-build-resolver`, `rust-build-resolver`, `pytorch-build-resolver`

### Architecture & Planning
- `architect`, `planner`, `code-architect`, `chief-of-staff`, `a11y-architect`

### Quality & Testing
- `tdd-guide`, `e2e-runner`, `database-reviewer`, `pr-test-analyzer`, `harness-optimizer`, `type-design-analyzer`

### Security & Performance
- `security-reviewer`, `performance-optimizer`, `silent-failure-hunter`

### Documentation & Exploration
- `doc-updater`, `docs-lookup`, `code-explorer`, `comment-analyzer`

### Refactoring & Analysis
- `refactor-cleaner`, `code-simplifier`, `conversation-analyzer`, `loop-operator`

### Specialized
- `seo-specialist`, `gan-evaluator`, `gan-generator`, `gan-planner`, `healthcare-reviewer`, `opensource-forker`, `opensource-packager`, `opensource-sanitizer`

---

## K-Dense Scientific — 147 skills (107 tagged K-Dense Inc.)

**147 SKILL.md files from [K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills)**, cloned into `~/.claude-scientific-skills/scientific-skills/`. The upstream repo was reorganized from `scientific-skills/` to `skills/`; `safe-install.sh` now handles both layouts (tries `skills/` first, falls back to `scientific-skills/`).

Of the 147 skills, **107 are tagged `skill-author: K-Dense Inc.`** in their SKILL.md frontmatter. The other 40 share skill names with skills already present from other sources (ECC, bioSkills), so they add no net-new entries.

All 147 flow to every harness through the `claude_extras` supplemental scan in `update-ecc.sh` (which collects skills present in `~/.claude/skills/` but absent from any source repo) plus the direct scan of `~/.claude-scientific-skills/scientific-skills/`.

The list below groups all 147 K-Dense skills by topic. Categories are topical, not filesystem-derived (since the skills live at the top level of the source repo's `skills/` directory).

### Bioinformatics & Genomics
- `scanpy`, `scvi-tools`, `cellxgene-census`, `pysam`, `biopython`, `bioservices`, `pyopenms`, `deeptools`, `pathml`, `gtars`, `matchms`, `etetoolkit`, `arboreto`, `geniml`, `gget`, `anndata`, `polars-bio`, `histolab`, `pyhealth`, `pydicom`, `neuropixels-analysis`, `omero-integration`, `pydeseq2`

### Cheminformatics & Drug Discovery
- `rdkit`, `datamol`, `deepchem`, `medchem`, `molfeat`, `diffdock`, `cobrapy`, `pytdc`, `esm`, `primekg`

### Proteomics, Structural Biology & Quantum
- `pymatgen`, `cirq`, `qutip`, `pennylane`, `qiskit`, `pymc`, `aeon`, `astropy`

### Clinical & Healthcare
- `clinical-decision-support`, `clinical-reports`, `treatment-plans`, `iso-13485-certification`, `usfiscaldata`

### Machine Learning & AI
- `scikit-learn`, `pytorch-lightning`, `transformers`, `torchdrug`, `stable-baselines3`, `pymoo`, `shap`, `dask`, `polars`, `vaex`, `networkx`, `simpy`, `pufferlib`, `umap-learn`

### Scientific Communication & Documentation
- `scientific-writing`, `scientific-slides`, `scientific-brainstorming`, `scientific-critical-thinking`, `pptx-posters`, `citation-management`, `literature-review`, `peer-review`, `paper-lookup`, `scholar-evaluation`, `venue-templates`, `research-grants`, `markitdown`

### Lab Automation & Platforms
- `benchling-integration`, `dnanexus-integration`, `opentrons-integration`, `labarchive-integration`, `latchbio-integration`, `protocolsio-integration`, `lamindb`, `pylabrobot`, `open-notebook`, `modal`

### Statistics & Data Visualization
- `scikit-bio`, `scikit-survival`, `statsmodels`, `sympy`, `exploratory-data-analysis`, `hypogenic`, `hypothesis-generation`, `matplotlib`, `seaborn`, `scientific-visualization`, `geopandas`, `geomaster`, `matlab`, `neurokit2`, `scientific-schematics`

### Research Tools & Resources
- `database-lookup`, `get-available-resources`, `research-lookup`, `market-research-reports`, `flowio`, `fluidsim`, `zarr-python`, `pyzotero`, `generate-image`

---

## ClawBio Bioinformatics — 90 skills (398 .py files)

From [ClawBio/ClawBio](https://github.com/ClawBio/ClawBio). Bioinformatics-native pipeline skills with executable Python scripts (398 `.py` files across 90 skills + 357 markdown files), installed on-disk via `--with-bio`.

Unlike other skill sources, ClawBio skills include runnable Python scripts alongside SKILL.md prompts, making them both prompt-based guidance and executable tools.

### Variant Analysis & Genomics
- `variant-annotation`, `vcf-annotator`, `fine-mapping`, `genome-compare`, `genome-match`, `archaic-introgression`, `hla-typing`

### Clinical & Pharmacogenomics
- `clinical-trial-finder`, `clinical-variant-reporter`, `clinpgx`, `pharmgx-reporter`, `wes-clinical-report-en`, `wes-clinical-report-es`, `nutrigx_advisor`, `drug-photo`

### RNA-seq & Single-cell
- `rnaseq-de`, `scrna-orchestrator`, `scrna-embedding`, `de-summary`, `cell-detection`, `proteomics-de`

### GWAS & Population Genetics
- `gwas-lookup`, `gwas-prs`, `claw-ancestry-pca`, `claw-metagenomics`, `recombinator`, `mendelian-randomisation`

### Epigenomics & Methylation
- `methylation-clock`

### Drug Discovery & Target Validation
- `target-validation-scorer`, `omics-target-evidence-mapper`

### UK Biobank & Large Cohorts
- `ukb-navigator`

### Data Processing & Reporting
- `seq-wrangler`, `data-extractor`, `multiqc-reporter`, `diff-visualizer`, `profile-report`

### Literature & Protocol Integration
- `pubmed-summariser`, `lit-synthesizer`, `bgpt-mcp`, `protocols-io`, `labstep`

### Ancestry & Social Genomics
- `claw-semantic-sim`, `soul2dna`, `equity-scorer`

### Structural & Functional Prediction
- `struct-predictor`

### Platform Bridges & Data Access
- `galaxy-bridge`, `bioconductor-bridge`, `illumina-bridge`, `bigquery-public`, `bio-orchestrator`

### Quality & Reproducibility
- `repro-enforcer`

### Key Capabilities
- **Executable Python scripts**: Each skill includes a `.py` script that can be run directly (e.g. `rnaseq_de.py`, `vcf_annotator.py`)
- **OpenClaw integration**: Skills declare `metadata.openclaw` with install requirements (`uv` packages, binaries)
- **Test suites**: Many skills include `tests/` directories with example data

### Access
- **All harnesses**: Installed on-disk via `./safe-install.sh --with-bio` (default: enabled)
- **Cache**: Included in `~/.claude/skills-cache/combined-skills.txt` after install

---

## GPTomics/bioSkills — 546 skills (63 categories)

From [GPTomics/bioSkills](https://github.com/GPTomics/bioSkills). Comprehensive bioinformatics skills organized into 63 categories, installed at depth-3 in `~/.claude/skills/<category>/<skill>/SKILL.md` — 546 on disk. Available on demand via the Skill tool, NOT injected into every session (zero token cost until invoked).

| Category | Skills | Category | Skills |
|----------|--------|----------|--------|
| `alignment` | 5 | `alignment-files` | 9 |
| `alternative-splicing` | 6 | `atac-seq` | 6 |
| `causal-genomics` | 5 | `chemoinformatics` | 7 |
| `chip-seq` | 7 | `clinical-biostatistics` | 6 |
| `clinical-databases` | 10 | `clip-seq` | 5 |
| `comparative-genomics` | 5 | `copy-number` | 4 |
| `crispr-screens` | 8 | `data-visualization` | 12 |
| `database-access` | 11 | `differential-expression` | 6 |
| `ecological-genomics` | 6 | `epidemiological-genomics` | 5 |
| `epitranscriptomics` | 5 | `experimental-design` | 4 |
| `expression-matrix` | 5 | `flow-cytometry` | 8 |
| `gene-regulatory-networks` | 5 | `genome-annotation` | 6 |
| `genome-assembly` | 8 | `genome-engineering` | 5 |
| `genome-intervals` | 7 | `hi-c-analysis` | 8 |
| `imaging-mass-cytometry` | 6 | `immunoinformatics` | 5 |
| `liquid-biopsy` | 6 | `long-read-sequencing` | 8 |
| `machine-learning` | 6 | `metabolomics` | 8 |
| `metagenomics` | 7 | `methylation-analysis` | 5 |
| `microbiome` | 6 | `multi-omics-integration` | 4 |
| `pathway-analysis` | 6 | `phasing-imputation` | 4 |
| `phylogenetics` | 8 | `population-genetics` | 6 |
| `primer-design` | 3 | `proteomics` | 9 |
| `read-alignment` | 4 | `read-qc` | 7 |
| `reporting` | 5 | `restriction-analysis` | 4 |
| `ribo-seq` | 5 | `rna-quantification` | 4 |
| `rna-structure` | 3 | `sequence-io` | 9 |
| `sequence-manipulation` | 7 | `single-cell` | 14 |
| `small-rna-seq` | 5 | `spatial-transcriptomics` | 11 |
| `structural-biology` | 6 | `systems-biology` | 5 |
| `tcr-bcr-analysis` | 5 | `temporal-genomics` | 5 |
| `variant-calling` | 13 | `workflow-management` | 4 |
| `workflows` | 41 | | |

### Access
- **All harnesses**: Installed by `scripts/install-bioskills.sh` into `~/.claude/skills/` then synced to all harnesses via `update-ecc.sh`
- **Default**: Enabled in `safe-install.sh` (use `--without-bioskills` to skip)

---

## NVIDIA BioNeMo — 35 skills

From [NVIDIA-BioNeMo/bionemo-agent-toolkit](https://github.com/NVIDIA-BioNeMo/bionemo-agent-toolkit) at `~/.claude-bionemo-skills/`. GPU-accelerated drug-discovery and structural-biology skills (35 SKILL.md across `nim-skills/`, `open-models-skills/`, `library-skills/`, `workflows/`, and `plugins/`):

- **NIM service wrappers**: `boltz2-nim`, `diffdock-nim`, `openfold2-nim`, `openfold3-nim`, `proteinmpnn-nim`, `rfdiffusion-nim`, `molmim-nim`, `genmol-nim`, `evo2-nim`, `msa-search-nim`
- **Design & pipeline workflows**: `protein-binder-design`, `drug-discovery-pipeline`, `msa-structure-prediction-pipeline`, plus the Complexa binder-design suite (`complexa-design`, `complexa-target`, `complexa-sweep`, `complexa-slurm`, `complexa-evaluate-pdbs`, …)
- **KERMT molecular pretraining**: `kermt-setup`, `kermt-pretrain-scratch`, `kermt-continue-pretrain`, `kermt-finetune`, `kermt-embed`, `kermt-infer`, `kermt-monitor`
- **Acceleration libraries**: `parabricks`, `nvMolKit`, `cuEquivariance`, `genomics-workflow-acceleration`

## ToolUniverse — 150 skills

From [mims-harvard/ToolUniverse](https://github.com/mims-harvard/ToolUniverse) at `~/.claude-tooluniverse/skills/`. Biomedical tool skills for drug discovery, precision oncology, and rare-disease diagnosis, wrapping 1,000+ ML models, datasets, and biomedical APIs (drug, gene, variant, and literature endpoints). 150 SKILL.md on disk, all net-new to the pool.

## OpenClaw-Medical — 896 skills

From [FreedomIntelligence/OpenClaw-Medical-Skills](https://github.com/FreedomIntelligence/OpenClaw-Medical-Skills) at `~/.claude-medical-skills/skills/`. Clinical-reasoning and medical-domain skills meta-aggregated from 12+ upstream repos (clinical workflows, genomics, drug discovery, regulatory). 896 SKILL.md on disk; 708 are net-new after de-duplicating against the bio/clinical skills already in the pool.

## operon — Swarup Lab workflows — 556 protocols

From [swaruplab/operon](https://github.com/swaruplab/operon) at `~/.claude-operon-skills/protocols/`. Single-cell and multi-omics analysis protocols (RNA-seq, scRNA-seq, ATAC-seq, ChIP-seq, WGS/WES, spatial, proteomics, GWAS). 556 SKILL.md on disk; 389 net-new after overlap with bioSkills/ClawBio.

## Nature-Paper-Skills — 18 skills

From [Boom5426/Nature-Paper-Skills](https://github.com/Boom5426/Nature-Paper-Skills) at `~/.claude-nature-paper-skills/` (MIT). Agent skills for Nature-style manuscript work — drafting, revision, and submission:

- **Core**: `paper-workflow`, `paper-bootstrap`, `scientific-writing`, `manuscript-optimizer`, `results-section-revision`, `figure-planner`, `citation-verifier`, `data-availability`, `submission-audit`, `rebuttal-response`
- **Venue**: `nature-portfolio-playbook`
- **Research & review**: `academic-researcher`, `paper-analyzer`, `results-analysis`, `paper-reviewer`
- **Optional**: `conference-paper-writing`, `reference-audit-guide`, `academic-presentations`

18 SKILL.md on disk; 17 net-new (`scientific-writing` overlaps K-Dense).

## Anthropic life-sciences — 6 skills

From [anthropics/life-sciences](https://github.com/anthropics/life-sciences) at `~/.claude-life-sciences/`. Anthropic's reference life-sciences skills: single-cell RNA QC, Nextflow development, clinical-trial protocol, and scientific problem selection.

## SkillGraph Bioinformatics (MCP)

From [variomeanalytics/bioinformatics-agent-skills](https://github.com/variomeanalytics/bioinformatics-agent-skills). Served dynamically via the SkillGraph MCP server at `https://skillgraph.pipette.bio/mcp`.

### Domain Breakdown

| Domain | Skills | Examples |
|--------|--------|----------|
| Variant analysis | 13 | variant-calling, vcf-filtering, snpeff-annotation |
| Single-cell / scRNA-seq | 12 | scanpy, seurat, cellranger, scvi |
| Database queries | 12 | clinvar, gnomad, cosmic, ensembl, uniprot |
| Drug discovery | 11 | docking, admet, drug-repurposing |
| Microbiome / metagenomics | 5 | kraken2, metaphlan, humann |
| Bulk RNA-seq | 4 | star-alignment, deseq2, featurecounts |
| Epigenomics | 4 | atacseq, chipseq, bisulfite |
| Pathway / enrichment | 4 | go-enrichment, gsea, reactome |
| Tooling | 4 | fastqc, multiqc, samtools |
| Spatial | 1 | spatial-transcriptomics |
| Proteomics / structural | 1 | alphafold |
| Other | 7 | assembly, alignment, phylogenetics |

### Key Capabilities
- **Knowledge graph**: skill-to-skill transitions (literature-backed plus ground-truth edges)
- **Pipeline routing**: Ask "what pipeline takes me from FASTQ to DEGs?" and get an evidence-based answer
- **Papers and tools** referenced across skill edges — query the live `skillgraph` MCP (`get_graph_stats`) for current counts

### Access
- **Claude Code CLI**: Automatically available via `skillgraph` MCP server in `~/.claude.json`
- **Claude Desktop**: Not supported (HTTP-type servers require Settings → Integrations in Desktop UI)

---

## Bipartite — 37 skills

From [matsen/bipartite](https://github.com/matsen/bipartite) — a research workflow CLI (`bip`) + Claude Code skills for connecting research programs to the outside world. Bipartite operates on a "nexus" (a git-backed JSONL directory) that stores your paper library, project context, and workflow coordination data.

The 37 skills cover five functional areas:

**Ideas coordination (manuscript sessions):**
- `bip-ms` — manuscript cold-start dashboard
- `bip-ms-poll` — quick poll of tracked EPICs and repos for new results
- `bip-ms-audit` — audit manuscript against implementation
- `bip-ms-sweep` — pre-share polish sweep of a TeX manuscript
- `bip-ms-tuckin` — persist manuscript session state before context reset

**Literature management:**
- `bip-lit` — unified reference library CLI guidance (search, import, cite)
- `bip-lit-edges` — add knowledge graph edges from TeX paper citations
- `bip-lit-extract` — extract paper references and concepts from LaTeX
- `bip-lit-import` — import Paperpile JSON export into bip library

**EPIC orchestration (agent worker coordination):**
- `bip-epic` — EPIC cold-start dashboard
- `bip-epic-spawn` — spawn a Claude session in a clone for an EPIC issue
- `bip-epic-poll` — quick poll of GitHub activity and clone status
- `bip-epic-handoff` — worker self-spawns follow-up issue and hands off
- `bip-epic-check` — review an EPIC issue for strategic clarity
- `bip-epic-tuckin` — persist orchestrator state before context reset
- `bip-epic-prepare-reboot` — quiesce tmux host before planned reboot
- `bip-epic-recover` — recover bip-epic sessions after host reboot

**Issue and PR management:**
- `bip-issue-check` — review an issue markdown file for completeness
- `bip-issue-file` — create or update GitHub issue from markdown file
- `bip-issue-next` — draft the next GitHub issue from PR follow-up or focus file
- `bip-issue-update` — re-evaluate an existing issue against current repo state
- `bip-issue-work` — read a GitHub issue and implement the work described
- `bip-pr-check` — quick PR readiness check
- `bip-pr-review` — comprehensive pre-merge quality checklist
- `bip-pr-land` — land a PR branch (squash merge, cleanup, return to main)

**Workflow coordination:**
- `bip-checkin` — check in on recent GitHub activity across tracked repos
- `bip-digest` — generate Slack activity digests from GitHub activity
- `bip-narrative` — generate thematic prose-style narrative digests
- `bip-spawn` — open a tmux window with a Claude Code session for an issue/PR
- `bip-scout` — check remote server CPU/memory/GPU availability via SSH
- `bip-board` — manage GitHub project boards
- `bip-comment-check` — fact-check a PR review comment against actual code
- `bip-decay-audit` — sweep a repo for decay modes in agent-written codebases
- `bip-kaizen` — reflect on what just happened and propose improvements
- `bip-plan` — enter plan mode with full context preserved
- `bip-marimo` — generate and edit marimo reactive notebooks
- `bip-tmux` — open a file in a tmux popup window using less

**Also installs 16 subagent definitions** into `~/.claude/agents/`:
`clean-code-reviewer`, `code-reuse-reviewer`, `issue-lead`, `journal-submission-checker`, `math-pr-summarizer`, `nextflow-pipeline-expert`, `pdf-proof-reader`, `pdf-question-answerer`, `plot-reviewer`, `scientific-tex-editor`, `snakemake-pipeline-expert`, `surprising-conclusion-skeptic`, `tex-grammar-checker`, `tex-verb-tense-checker`, `topic-sentence-stickler`, `zig-code-reviewer`.

**Installation:** `git clone https://github.com/matsen/bipartite ~/.claude-bipartite && cd ~/.claude-bipartite && make install` (requires Go 1.24+ for the `bip` CLI).

## Personal Learned Skills — varies

Auto-extracted generalizable patterns from your own sessions via a 4-stage ALMA-inspired pipeline. Unlike all other sources, these skills evolve over time — the more you correct your harness, the better it gets.

### Pipeline Stages

| Stage | What it does |
|-------|-------------|
| **Ingestion** | Parses conversation histories, classifies user corrections into memory types: `anti_pattern`, `heuristic`, `preference`, `domain_knowledge` |
| **Learning** | Groups similar corrections (Jaccard ≥ 0.5), requires 3+ unique sessions (configurable via `--min-occurrences`), confidence ≥ 0.5, cross-project bonus |
| **Consolidation** | Deduplicates (token overlap ≥ 0.85), abstracts into condition+strategy+anti-pattern form via keyword mapping or LLM distillation (`--llm`), quality gates reject empty/generic/single-project patterns. **For LLM mode, distillation is batched** (see *Performance methodology* below) |
| **Output** | Writes concise SKILL.md files (≤50 lines) with YAML frontmatter |

### Performance methodology

The naive pipeline called Ollama **once per correction group**: 580 groups × ~30 s each = ~4.8 hours of sequential LLM calls — far too slow to run on demand. Five design choices make the modern pipeline tractable:

| Innovation | What it does | Effect |
|------------|--------------|--------|
| **Batched LLM distillation** | `_llm_distill_batch()` packs 20 groups into a single Ollama prompt and asks for one JSON array back, instead of N separate calls. Each group is still validated independently. | 20× fewer LLM calls (580 → 29) |
| **HTTP connection pooling** | A single `requests.Session()` is reused across all batch calls, instead of opening a fresh TCP connection per request. | Eliminates TCP/TLS handshake cost |
| **Parallel batch workers (16)** | A `ThreadPoolExecutor(max_workers=16)` runs batches concurrently against Ollama, which queues extras gracefully. | 16× wall-clock speedup for the distillation stage |
| **Isolated learning venv** | The script's `_ensure_deps()` creates an isolated Python venv at `~/.claude/.venv` for `scikit-learn`, `numpy`, `requests`. Uses `uv` when available (PEP 668-safe on macOS Homebrew Python 3.12+), falls back to `pip install --user`. Re-execs itself with the venv python if needed. | No conflicts with system packages, no PEP 668 errors on externally-managed Python installs |
| **Lazy imports inside the hot path** | `import requests`, `import json` are imported inside `_llm_distill_batch()` (not at module top), so users running `--no-llm` don't pay the import cost and don't crash on a missing `requests` for unrelated paths. | Avoids top-level import errors when only the keyword-based code path is used |

**Combined speedup:** ~580 groups that would have taken ~4.8 hours now complete in **~2-5 minutes** — a **30-50× end-to-end improvement**. The number of LLM calls is constant (29) regardless of input size past one batch.

**Fallback behavior:** If a batch fails to parse JSON, the function falls back to per-group distillation for just that batch — gracefully degrading rather than aborting the whole run. If Ollama is unavailable, the keyword-mapping path (no LLM) is used as before.

### Memory Types

| Type | Generalizable? | What it captures |
|------|----------------|-----------------|
| `heuristic` | ✅ Yes | Repeated successful strategies → "When X, do Y" |
| `anti_pattern` | ✅ Yes | Repeated failed approaches → "Don't do X — instead Z" |
| `preference` | ❌ Per-user | Style/communication preferences |
| `domain_knowledge` | ❌ Rejected | Project-specific facts (not generalizable) |

### Skill Format

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

### Feedback & Decay

- **Feedback score** = (uses − ignores) / total loads (neutral 0.5 until 5 samples)
- **Decay factor** = exp(−0.693 × days / 90) — skills unused for 90 days halve in relevance
- Skills with feedback × decay < 0.2 get **archived** (not deleted) to `learned/archived/`
- Run `learn-stats` to check scores, `learn-prune` to archive low-signal skills

### Access
- **All harnesses**: Synced via `sync-learned-skills.sh` → `~/.claude/skills/learned/`, `~/.openclaw/workspace/skills/`, `~/.pi/agent/skills/`, `~/.codex/skills/`
- **Automatic**: Runs on `install.sh` (default), `update-ecc.sh` (Step 4)
- **Manual**: `learn-sync`, `learn-sync-dry`, `learn-stats`, `learn-prune`

### Current Learned Skills

Skills in `~/.claude/skills/learned/` grow over time as you correct your harness. Run `learn-stats` to see the current list and their confidence/decay scores. The pipeline currently produces ~20-45 skills depending on your session history depth.