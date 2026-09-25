#!/bin/bash
# Extract learned skills, then use the same ownership-aware sync as upstream skills.
# --dry-run never creates directories/logs/cache; --sync-only is entirely offline.
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="${SKILLWEAVE_PYTHON:-$HOME/.claude/skillweave-venv/bin/python}"
if [ ! -x "$PYTHON" ]; then PYTHON="${SKILLWEAVE_PYTHON:-python3}"; fi
SYNC_ONLY=false
STATS=false
PRUNE=false
USE_LLM=true
EXTRACT_ARGS=()
SYNC_ARGS=(--offline)
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) EXTRACT_ARGS+=(--dry-run); SYNC_ARGS+=(--dry-run); shift ;;
        --verbose) EXTRACT_ARGS+=(--verbose); shift ;;
        --sync-only) SYNC_ONLY=true; shift ;;
        --stats) STATS=true; shift ;;
        --prune) PRUNE=true; shift ;;
        --no-llm) USE_LLM=false; shift ;;
        --no-prune) SYNC_ARGS+=(--no-prune); shift ;;
        --llm-backend|--llm-model|--llm-base-url|--llm-timeout|--llm-context|--llm-max-tokens)
            [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
            EXTRACT_ARGS+=("$1" "$2"); shift 2 ;;
        --llm-allow-remote) EXTRACT_ARGS+=("$1"); shift ;;
        --help|-h)
            echo "Usage: $0 [--sync-only|--stats|--prune] [--dry-run] [--verbose] [--no-llm] [--llm-backend ollama|llama.cpp] [--llm-model MODEL] [--llm-base-url URL] [--no-prune]"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done
if $STATS; then
    exec "$PYTHON" -B "$SCRIPT_DIR/extract-conversation-skills.py" --stats "${EXTRACT_ARGS[@]}"
fi
if $PRUNE; then
    "$PYTHON" -B "$SCRIPT_DIR/extract-conversation-skills.py" --prune "${EXTRACT_ARGS[@]}"
elif ! $SYNC_ONLY; then
    $USE_LLM && EXTRACT_ARGS+=(--llm)
    "$PYTHON" -B "$SCRIPT_DIR/extract-conversation-skills.py" --output "$HOME/.claude/skills/learned" --incremental "${EXTRACT_ARGS[@]}"
fi
# A failed extraction/prune exits above, before propagating or reporting success.
bash "$SCRIPT_DIR/scripts/update-ecc.sh" "${SYNC_ARGS[@]}"
