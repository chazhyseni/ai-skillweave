#!/bin/bash
# Sourced by the installer; never changes system/user Python packages.
skillweave_python() {
    local root="$1" learning="${2:-false}"
    local venv="$HOME/.claude/skillweave-venv"
    command -v python3 >/dev/null 2>&1 || { echo 'Python 3 is required.' >&2; return 1; }
    if [ -L "$venv" ]; then echo "Refusing symlinked environment: $venv" >&2; return 1; fi
    if [ ! -x "$venv/bin/python" ]; then
        python3 -m venv "$venv" || { echo 'Cannot create venv. Install Python venv/pip support with your package manager.' >&2; return 1; }
    fi
    if ! "$venv/bin/python" -c 'import yaml, json5' >/dev/null 2>&1; then
        "$venv/bin/python" -m pip install --disable-pip-version-check -r "$root/requirements.txt" || return 1
    fi
    if [ "$learning" = true ] && ! "$venv/bin/python" -c 'import sentence_transformers, sklearn' >/dev/null 2>&1; then
        "$venv/bin/python" -m pip install --disable-pip-version-check -r "$root/requirements-learning.txt" || return 1
    fi
    export SKILLWEAVE_PYTHON="$venv/bin/python"
}
