#!/bin/bash
# bioSkills uses the same source selection and ownership tracking as every update.
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGS=(--with-bioskills); LIST=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run|--offline) ARGS+=("$1"); shift ;;
        --update) shift ;;
        --categories)
            [ "$#" -ge 2 ] && [ -n "$2" ] && [[ "$2" != --* ]] || { echo '--categories requires comma-separated names' >&2; exit 1; }
            ARGS+=(--bioskills-categories "$2"); shift 2 ;;
        --categories=*) ARGS+=(--bioskills-categories "${1#*=}"); shift ;;
        --list) LIST=true; shift ;;
        --help|-h)
            echo 'Usage: install-bioskills.sh [--categories NAME,NAME] [--update] [--offline] [--dry-run] [--list]'
            echo '--list reads local cache only. bioSkills upstream is archived; review before use.'
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done
if $LIST; then
    python3 - <<'PY'
from pathlib import Path
root = Path.home() / '.claude/skills-cache/bioskills-src'
if not root.is_dir():
    raise SystemExit('No local bioSkills checkout. Install explicitly before listing categories.')
for child in sorted(root.iterdir()):
    count = sum(1 for p in child.glob('*/SKILL.md')) if child.is_dir() else 0
    if count:
        print(f'{child.name}: {count} skills')
PY
else
    exec bash "$SCRIPT_DIR/update-ecc.sh" "${ARGS[@]}"
fi
