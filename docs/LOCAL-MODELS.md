# Local models: Ollama and llama.cpp

Skill delivery needs no model server or subscription. Model configuration is
opt-in; the installer never downloads weights or starts a server.

## Choose a model

Candidates below reflect September 2026 listings, **not benchmark rankings**.
The small default `qwen3.5:4b` is a starting point, not a universal coding-agent
recommendation. Qwen3.8 and Ornith are newer alternatives to evaluate.

| Ollama tag | Model-layer size | Starting hardware estimate* |
|---|---:|---|
| [`qwen3.5:4b`](https://ollama.com/library/qwen3.5:4b) | 3.39 GB | 8–16 GB memory |
| [`qwen3.5:9b`](https://ollama.com/library/qwen3.5:9b) | 6.59 GB | 16–24 GB |
| [`ornith:9b`](https://ollama.com/library/ornith:9b) | 5.63 GB | 16–24 GB |
| [`qwen3.8:27b`](https://ollama.com/library/qwen3.8:27b) | 16.81 GB + 0.93 GB projector | 32–48 GB or more |
| [`ornith:35b`](https://ollama.com/library/ornith:35b) | 21.17 GB | 32–48 GB or more |

*Estimates, not measured fit. Weights are only part of runtime memory: leave room
for the OS, KV cache, context, buffers and other applications. MoE active
parameters do not equal stored weight size. Artifact sizes come from the Ollama
registry manifests ([4B](https://registry.ollama.ai/v2/library/qwen3.5/manifests/4b),
[9B](https://registry.ollama.ai/v2/library/qwen3.5/manifests/9b),
[27B](https://registry.ollama.ai/v2/library/qwen3.8/manifests/27b),
[Ornith 9B](https://registry.ollama.ai/v2/library/ornith/manifests/9b),
[35B](https://registry.ollama.ai/v2/library/ornith/manifests/35b)). Rechecked
2026-09-25. Record digests and quantization when comparing models; tags can change.

For modest Macs/CPUs, evaluate Qwen3.5 4B/9B or Ornith 9B before the 27B/35B
options. Ornith is coding-oriented; Qwen3.5 is a broader candidate. These are
hardware-conscious shortlists, not measured quality rankings. Avoid `latest`
in reproducible setups: installed aliases can refer to a different model size.
Select a specific local tag, not `:cloud`, and verify `ollama show TAG`.

**Size context for the complete prompt, not just the question.** The 608-skill
catalog alone measured roughly 14–15K OpenAI/Qwen tokens before tools, system
instructions, conversation and output. A 16K context is therefore unsuitable for
that full-library agent session. Keep all needed skills available; provision a
model/server with sufficient usable context instead of silently dropping skills.

The examples below use **64K context and one server slot** for a full-library
setup; this is a sizing example, not a measured fit guarantee. Account for KV
cache and other memory, inspect actual prompt usage, and increase context if the
complete workload requires it. Compact extraction jobs or deliberately smaller
catalogs can use 16K or less. Increasing a context limit does not itself add input
tokens, but may increase allocated memory. Advertised model maximum context is
not the server's configured allocation. Test realistic prompts and tool calling.

## Ollama

Install from [Ollama](https://ollama.com/download), then explicitly choose weights:

```bash
ollama pull qwen3.5:4b
ollama show qwen3.5:4b
ollama serve  # only if the app/server is not already running
```

```bash
bash scripts/setup-pi.sh --backend ollama --model qwen3.5:4b \
  --context 65536 --max-tokens 4096
```

Local models need no Ollama subscription. [Cloud models](https://docs.ollama.com/cloud)
are separate, with authentication, quotas and possible charges. The extractor
sends `num_ctx` explicitly; other harnesses may need server/model context setup
too. A client `contextWindow` field alone does not allocate server memory.

## llama.cpp

Use a current [llama.cpp](https://github.com/ggml-org/llama.cpp) build supporting
your GGUF model architecture and chat template. CPU, Apple Metal and GPU builds
are available; no Ollama account is required.
The published stable release checked on 2026-09-25 is
[`v0.5.0`](https://github.com/ggml-org/llama.cpp/releases/tag/v0.5.0), whose release
page points to platform binaries under nightly `b11146`. On Apple Silicon use a
Metal-enabled arm64 build; on Linux match CPU/CUDA/Vulkan builds to your hardware.
Check `llama-server --version` rather than assuming a package-manager install is
current. Upgrading the server does not require an Ollama subscription.

```bash
brew install llama.cpp  # macOS; other platforms: upstream build instructions
llama-server -m /absolute/path/to/model.gguf \
  --alias local-agent --host 127.0.0.1 --port 8080 \
  -c 65536 -np 1 --jinja
```

Choose the GGUF and quantization for your hardware and license requirements.
`--jinja` enables chat-template handling; compatible tool calling still needs
verification. Keep the server on loopback unless you deliberately secure it.

```bash
curl --fail http://127.0.0.1:8080/health
curl --fail http://127.0.0.1:8080/v1/models
bash scripts/setup-omp-model.sh --backend llama.cpp --model local-agent \
  --base-url http://127.0.0.1:8080/v1 --context 65536 --max-tokens 4096
omp --model skillweave-local/local-agent
```

Pi also now documents a built-in [llama.cpp router integration](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/llama-cpp.md)
with `/llama` for on-demand GGUF loading. The explicit single-server setup above
remains simpler when sharing one endpoint across harnesses.

## Compatibility and settings

| Surface | Contract |
|---|---|
| Extractor | Ollama `/api/generate`; llama.cpp `/v1/chat/completions` |
| Pi | Merged `models.json` provider and explicit `settings.json` model selection |
| oh-my-pi | Native `models.yml` provider; select with `--model`; auxiliary roles unchanged |
| OpenClaw | Native Ollama API or llama.cpp OpenAI-compatible provider; preserves gateway/auth/plugins |
| Codex | `skillweave-local.config.toml` profile; **Codex 0.134.0+ and `/v1/responses` required** |
| Ollama launch | Ollama-only mappings, not a llama.cpp transport |

Select Codex with `codex --profile skillweave-local`. The separate
[profile](https://learn.chatgpt.com/docs/config-file/config-advanced#profiles)
keeps existing config/trust intact and uses workspace-write/on-request, not
unrestricted access. Claude/Copilot native skill delivery does not configure
their inference APIs.

Setup flags: `--backend`, `--model`, `--base-url`, `--context`, `--max-tokens`,
`--timeout`. Extraction uses the same flags prefixed `--llm-`.
Environment equivalents use `SKILLWEAVE_LLM_` plus `BACKEND`, `MODEL`,
`BASE_URL`, `CONTEXT`, `MAX_TOKENS`, or `TIMEOUT`; CLI values take precedence.
Credentials use **`SKILLWEAVE_LLM_API_KEY` only**, never command-line secrets.

## Privacy and validation

The extractor uses one chosen backend: no cloud fallback, inherited proxy or
HTTP redirect. Remote URLs/cloud tags require `--allow-remote` (extraction:
`--llm-allow-remote`) or `SKILLWEAVE_LLM_ALLOW_REMOTE=1`. A locally configured
proxy/alias can still route remotely; inspect your server configuration.

Local inference does not disable remote MCP tools, telemetry or a harness's
auxiliary/fallback models. Review those separately before processing histories.
For custom OMP profiles, model setup and skill delivery share one resolver.
Use `OMP_PROFILE=research` for the profile you launch with `omp --profile research`,
or align `SKILLWEAVE_OMP_AGENT_DIR` with OMP's `PI_CODING_AGENT_DIR`.
Model wrappers use the installed Skillweave Python environment when available,
so an existing YAML model configuration does not depend on system-wide PyYAML.

Validate a short completion, one harmless tool task, and a representative skill
with supporting assets. Repeat at realistic context size, recording memory,
latency and tool success. The optional Hugging Face source provides model
selection, weight-sizing and evaluation skills; none certifies scientific or
clinical correctness.

## Verification scope

A real CPU llama-server using the already-installed Ornith 9B GGUF returned
`LOCAL_INFERENCE_OK` through `ModelBackend.complete` with a 4096-token context,
512-token output limit and thinking disabled. This verifies the actual
`/v1/chat/completions` transport, not agentic tool accuracy or macOS performance.
No weights were downloaded for that check. Repeat the tool/context checks above
on the destination hardware before selecting a production model.
