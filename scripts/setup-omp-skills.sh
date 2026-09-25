#!/bin/bash
# Native OMP discovery: getAgentDir()/skills/<name>/SKILL.md, not ~/.pi.
# Default agent dir plus existing profile dirs; SKILLWEAVE_OMP_AGENT_DIR overrides.
# Upstream: can1357/oh-my-pi docs/skills.md and src/discovery/builtin.ts.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/update-ecc.sh" --offline --harness omp "$@"
