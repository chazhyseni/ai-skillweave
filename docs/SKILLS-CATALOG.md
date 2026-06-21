# Skills Catalog

Overview of all skills available through ai-skillweave, organized by source and category.

**Total: 928 unique source-skill SKILL.md files across 6 upstream repos (ECC 272 + K-Dense 0 + ClawBio 89 + bioSkills 550 + Anthropic 17 + Codex curated 0) plus personal learned skills (varies, ~10+ currently). After deduplication and harness-specific handling, post-install counts are Claude 1,735 / OpenClaw 1,150 / Codex 811 / Pi 61 — see the README's "What Each Harness Gets" table for delivery details.**

---

## Source 1: Everything Claude Code (ECC) — 272 skills

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

## Source 2: ECC Commands — 79 commands

Slash-command skills invoked with `/command` in Claude Code. From [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code).

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

## Source 3: ECC Agents — 48 agents

Specialized AI agents for focused review, build, and planning tasks. From [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code).

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

## Source 4: K-Dense Scientific — 0 skills (upstream snapshot empty)

The repo is cloned and the framework is in place, but the upstream `scientific-skills/` directory is **currently empty in the snapshot we track**. When K-Dense publishes skill definitions, they will be auto-included here.

### Bioinformatics
- `scanpy`, `scvelo`, `scvi-tools`, `pydeseq2`, `pysam`, `biopython`, `bioservices`, `pyopenms`, `deeptools`, `pathml`, `cellxgene-census`, `gtars`, `matchms`, `etetoolkit`, `phylogenetics`, `arboreto`, `geniml`, `gget`, `tiledbvcf`, `polars-bio`

### Cheminformatics & Drug Discovery
- `rdkit`, `datamol`, `deepchem`, `medchem`, `molfeat`, `diffdock`, `cobrapy`, `pytdc`, `dhdna-profiler`, `glycoengineering`, `rowan`

### Genomics & Variant Analysis
- `depmap`, `esm`, `anndata`, `adaptyv`, `bgpt-paper-search`, `primekg`

### Proteomics & Structural Biology
- `pymatgen`, `molecular-dynamics`, `cirq`, `qutip`, `pennylane`

### Clinical & Healthcare
- `clinical-decision-support`, `clinical-reports`, `treatment-plans`, `pyhealth`, `pydicom`, `histolab`

### Machine Learning & AI
- `scikit-learn`, `pytorch-lightning`, `transformers`, `torch-geometric`, `torchdrug`, `stable-baselines3`, `pymoo`, `pymc`, `shap`, `dask`, `polars`, `vaex`, `networkx`, `simpy`, `pufferlib`

### Data Visualization
- `matplotlib`, `seaborn`, `scientific-visualization`, `infographics`, `scientific-schematics`, `umap-learn`

### Statistics & Analysis
- `statistical-analysis`, `statsmodels`, `scikit-survival`, `scikit-bio`, `sympy`, `exploratory-data-analysis`, `hypogenic`, `hypothesis-generation`, `what-if-oracle`, `timesfm-forecasting`

### Scientific Communication
- `scientific-writing`, `scientific-slides`, `scientific-brainstorming`, `scientific-critical-thinking`, `latex-posters`, `pptx-posters`, `citation-management`, `literature-review`, `peer-review`, `paper-lookup`, `paperzilla`, `scholar-evaluation`, `venue-templates`, `research-grants`

### Lab Automation & Platforms
- `benchling-integration`, `dnanexus-integration`, `opentrons-integration`, `ginkgo-cloud-lab`, `labarchive-integration`, `latchbio-integration`, `lamindb`, `pylabrobot`, `open-notebook`, `modal`

### Document & Data Formats
- `pdf`, `docx`, `xlsx`, `pptx`, `markitdown`, `markdown-mermaid-writing`

### Neuroimaging & Electrophysiology
- `neurokit2`, `neuropixels-analysis`, `imaging-data-commons`, `omero-integration`, `flowio`, `fluidsim`

### Database & Resource Lookup
- `database-lookup`, `get-available-resources`, `research-lookup`, `market-research-reports`, `usfiscaldata`

### Computing & Optimization
- `optimize-for-gpu`, `parallel-web`, `qiskit`, `cirq`, `zarr-python`, `aeon`, `astropy`, `qutip`, `pymc`, `simpy`

### Creative & Ideation
- `consciousness-council`, `generate-image`

---

## Source 5: ClawBio Bioinformatics — 89 skills

From [ClawBio/ClawBio](https://github.com/ClawBio/ClawBio). Bioinformatics-native pipeline skills with executable Python scripts (398 `.py` files across the 89 skills), installed on-disk via `--with-bio`.

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

## Source 6: GPTomics/bioSkills — 550 skills (63 categories)

From [GPTomics/bioSkills](https://github.com/GPTomics/bioSkills). Comprehensive bioinformatics skills organized into 63 categories, installed at depth-3 in `~/.claude/skills/<category>/<skill>/SKILL.md`. Available on-demand via the Skill tool — NOT injected into every session (zero token cost until invoked).

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

## Source 7: SkillGraph Bioinformatics (MCP)

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
- **Knowledge graph**: 483 transitions between skills (254 literature-backed, 127 ground truth)
- **Pipeline routing**: Ask "what pipeline takes me from FASTQ to DEGs?" and get an evidence-based answer
- **11,337 papers** referenced across skill edges
- **301 tools** covered across all skills

### Access
- **Claude Code CLI**: Automatically available via `skillgraph` MCP server in `~/.claude.json`
- **Claude Desktop**: Not supported (HTTP-type servers require Settings → Integrations in Desktop UI)

---

## Source 8: Personal Learned Skills — varies

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