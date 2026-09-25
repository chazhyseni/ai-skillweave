#!/bin/bash
# Configure skills and installed harnesses without installing system packages.
set -eo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
error() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'HELP'
Usage: bash install.sh [OPTIONS]
  --only TARGET       skills|claude|copilot|codex|pi|omp|openclaw|hermes|ollama|beads
                      Without --only: skills plus already installed harnesses.
  --skip-skills       Do not fetch skills or change shell integration
  --with-science / --without-science     Select scientific skills
  --with-curated / --without-curated     Select Anthropic/OpenAI skills
  --with-bio / --without-bio             Select ClawBio skills
  --with-bioskills / --without-bioskills Select GPTomics skills
  --with-huggingface / --without-huggingface  Focused Hugging Face skills
                      First install defaults to ECC only; choices persist.
  --learn             Install isolated learning dependencies and extract skills
  --no-learn          Skip learning dependencies, extraction and hooks (default)
  --no-llm            Regex-only extraction when --learn is selected
  --offline          Propagate existing checkouts without fetching
  --backend NAME      Opt in to ollama or llama.cpp model configuration
  --model MODEL       Model ID/server alias (implies ollama unless --backend set)
  --base-url URL      Backend URL; loopback by default
  --context N         Context window; --max-tokens N limits generation
  --allow-remote      Explicitly permit a non-loopback model endpoint
  --uninstall        Remove managed skills/shell integration, preserve user data
  --verify           Run diagnostics only
  --help, -h         Show help
No system/global packages, harness binaries, models or subscriptions are installed.
Install chosen harnesses yourself. Existing model choices are preserved by default.
Skills require git and Python 3 with venv/pip; dependencies use ~/.claude/skillweave-venv.
HELP
}
ONLY=""; SKIP_SKILLS=false; LEARN=false; ACTION=install
SKILL_ARGS=(); MODEL_ARGS=(); BACKEND=""; MODEL_REQUESTED=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --only|--backend|--model|--base-url|--context|--max-tokens)
            [ "$#" -ge 2 ] && [ -n "$2" ] && [[ "$2" != --* ]] || error "$1 requires a value"
            case "$1" in
                --only) ONLY="$2" ;;
                --backend) BACKEND="$2"; export SKILLWEAVE_LLM_BACKEND="$2"; MODEL_ARGS+=("$1" "$2"); MODEL_REQUESTED=true ;;
                *)
                    case "$1" in
                        --model) export SKILLWEAVE_LLM_MODEL="$2" ;;
                        --base-url) export SKILLWEAVE_LLM_BASE_URL="$2" ;;
                        --context|--max-tokens)
                            [[ "$2" =~ ^[1-9][0-9]*$ ]] || error "$1 requires a positive integer"
                            if [ "$1" = --context ]; then export SKILLWEAVE_LLM_CONTEXT="$2"; else export SKILLWEAVE_LLM_MAX_TOKENS="$2"; fi ;;
                    esac
                    MODEL_ARGS+=("$1" "$2"); MODEL_REQUESTED=true ;;
            esac
            shift 2 ;;
        --allow-remote) export SKILLWEAVE_LLM_ALLOW_REMOTE=1; MODEL_ARGS+=("$1"); MODEL_REQUESTED=true; shift ;;
        --with-science|--without-science|--with-curated|--without-curated|--with-bio|--without-bio|--with-bioskills|--without-bioskills|--with-huggingface|--without-huggingface|--offline|--no-llm)
            SKILL_ARGS+=("$1"); shift ;;
        --learn) LEARN=true; shift ;;
        --no-learn) LEARN=false; shift ;;
        --skip-skills) SKIP_SKILLS=true; shift ;;
        --uninstall|--verify) [ "$ACTION" = install ] || error 'Choose only one action'; ACTION="${1#--}"; shift ;;
        --help|-h) usage; exit 0 ;;
        *) error "Unknown option: $1 (see --help)" ;;
    esac
done
case "$ONLY" in ''|skills|claude|copilot|codex|pi|omp|openclaw|hermes|ollama|beads) ;; *) error "Unknown target: $ONLY" ;; esac
case "$BACKEND" in ''|ollama|llama.cpp) ;; *) error "Unknown backend: $BACKEND" ;; esac
if [ "$ACTION" = uninstall ]; then exec bash "$REPO_DIR/safe-install.sh" --uninstall; fi
if [ "$ACTION" = verify ]; then exec bash "$REPO_DIR/scripts/verify.sh"; fi
if $LEARN && { $SKIP_SKILLS || { [ -n "$ONLY" ] && [ "$ONLY" != skills ]; }; }; then
    error '--learn requires the skills layer (use --only skills --learn, without --skip-skills).'
fi
command -v python3 >/dev/null 2>&1 || error 'Python 3 is required; install it with your package manager.'
# Validate backend options before any installation side effects.
if $MODEL_REQUESTED; then
    python3 "$REPO_DIR/scripts/setup_model_backend.py" pi --validate-only "${MODEL_ARGS[@]}"
    [ -n "$BACKEND" ] || BACKEND=ollama
fi
if $LEARN; then SKILL_ARGS+=(--learn); else SKILL_ARGS+=(--no-learn); fi
if ! $SKIP_SKILLS && { [ -z "$ONLY" ] || [ "$ONLY" = skills ]; }; then
    bash "$REPO_DIR/safe-install.sh" "${SKILL_ARGS[@]}"
fi
selected() {
    if [ -n "$ONLY" ]; then [ "$ONLY" = "$1" ]; else command -v "$1" >/dev/null 2>&1; fi
}
require_harness() {
    command -v "$1" >/dev/null 2>&1 || error "$1 is not installed. Install it from its official documentation, then re-run --only $1."
}
# A targeted install only propagates to that harness; it never clones sources.
if [ -n "$ONLY" ] && ! $SKIP_SKILLS; then
    case "$ONLY" in
        claude|copilot|codex|pi|omp|openclaw|hermes)
            require_harness "$ONLY"
            source "$REPO_DIR/scripts/bootstrap-python.sh"
            skillweave_python "$REPO_DIR" false
            if [ "$ONLY" = omp ]; then
                bash "$REPO_DIR/scripts/setup-omp-skills.sh"
            else
                bash "$REPO_DIR/scripts/update-ecc.sh" --offline --no-learn --harness "$ONLY"
            fi
            ;;
    esac
fi
if selected claude; then
    require_harness claude
    bash "$REPO_DIR/scripts/setup-mcp.sh"
    bash "$REPO_DIR/scripts/setup-claude-md.sh"
    bash "$REPO_DIR/scripts/setup-hooks.sh"
    if $LEARN; then bash "$REPO_DIR/scripts/setup-learning-hook.sh"; fi
fi
if selected copilot; then
    require_harness copilot
    bash "$REPO_DIR/scripts/setup-copilot.sh"
fi
for target in codex pi openclaw; do
    if selected "$target"; then
        require_harness "$target"
        if $MODEL_REQUESTED; then
            bash "$REPO_DIR/scripts/setup-$target.sh" "${MODEL_ARGS[@]}"
        else
            printf '%s: preserving model configuration (use --backend to configure).\n' "$target"
        fi
    fi
done
if selected omp; then
    require_harness omp
    if $MODEL_REQUESTED; then bash "$REPO_DIR/scripts/setup-omp-model.sh" "${MODEL_ARGS[@]}"; fi
fi
if [ "$ONLY" = ollama ]; then
    require_harness ollama
    [ "$BACKEND" != llama.cpp ] || error '--only ollama requires --backend ollama'
    bash "$REPO_DIR/scripts/setup-ollama-config.sh" "${MODEL_ARGS[@]}"
fi
# Beads is opt-in: never initialize the repository during the default install.
if [ "$ONLY" = beads ]; then bash "$REPO_DIR/scripts/setup-beads.sh" --skip-init; fi
printf 'Setup complete. Open a new shell to activate skills aliases. Run bash install.sh --verify for diagnostics.\n'
