#!/bin/bash
# Maintain only the explicitly marked ai-skillweave section of global instructions.
set -eo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORCE=false
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=true ;;
        --help|-h) echo 'Usage: setup-claude-md.sh [--force] (--force replaces the whole file, with backup)'; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done
command -v python3 >/dev/null 2>&1 || { echo 'Python 3 is required.' >&2; exit 1; }
python3 - "$REPO_DIR/configs/global-claude-md.md" "$FORCE" <<'PY'
import re, shutil, sys
from pathlib import Path
path = Path.home() / '.claude/CLAUDE.md'
start = '# --- ai-skillweave managed section ---'
end = '# --- end ai-skillweave managed section ---'
old = path.read_text() if path.exists() else ''
block = start + '\n' + Path(sys.argv[1]).read_text().rstrip('\n') + '\n' + end + '\n'
if sys.argv[2] == 'true':
    new = block
elif start in old:
    pattern = re.escape(start) + r'.*?' + re.escape(end) + r'\n?'
    if len(re.findall(pattern, old, flags=re.S)) != 1 or old.count(start) != 1:
        raise SystemExit('Malformed managed CLAUDE.md section; repair it before retrying.')
    new = re.sub(pattern, lambda _: block, old, flags=re.S)
else:
    new = (old.rstrip('\n') + '\n\n' if old else '') + block
if new != old:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        backup = path.with_name(path.name + '.skillweave.bak')
        if not backup.exists():
            shutil.copy2(path, backup)
    path.write_text(new)
print(f'Global instructions configured: {path}')
PY
