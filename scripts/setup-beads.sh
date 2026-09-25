#!/bin/bash
# Optional beads integration; never installs packages or initializes a repo implicitly.
set -eo pipefail
INIT=false; FORCE=false
for arg in "$@"; do
    case "$arg" in
        --init) INIT=true ;;
        --skip-init) INIT=false ;;
        --force) FORCE=true ;;
        --help|-h)
            echo 'Usage: setup-beads.sh [--init|--skip-init] [--force]'
            echo 'Requires bd and beads-mcp already installed. --init explicitly initializes the current directory.'
            echo 'Install separately: https://github.com/gastownhall/beads and uv tool install beads-mcp'
            exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done
for cmd in python3 bd beads-mcp; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Missing $cmd; see setup-beads.sh --help. No packages were installed." >&2; exit 1; }
done
python3 - "$FORCE" "$(command -v beads-mcp)" <<'PY'
import json, shutil, sys
from pathlib import Path
for path in (Path.home() / '.claude.json', Path.home() / '.copilot/mcp-config.json'):
    if not path.is_file():
        print(f'Skipped absent config: {path}')
        continue
    config = json.loads(path.read_text())
    servers = config.setdefault('mcpServers', {})
    if 'beads' in servers and sys.argv[1] != 'true':
        print(f'Preserved existing beads entry: {path}')
        continue
    backup = path.with_name(path.name + '.skillweave.bak')
    if not backup.exists():
        shutil.copy2(path, backup)
    servers['beads'] = {'command': sys.argv[2], 'args': []}
    path.write_text(json.dumps(config, indent=2) + '\n')
    print(f'Configured beads: {path}')
PY
if $INIT && [ ! -d .beads ]; then bd init --stealth; fi
