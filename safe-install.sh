#!/bin/bash
# Install skills through the same ownership-aware engine used by updates.
set -eo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
error() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'HELP'
Usage: bash safe-install.sh [OPTIONS]
  --with-science / --without-science     K-Dense scientific skills
  --with-curated / --without-curated     Anthropic/OpenAI skills
  --with-bio / --without-bio             ClawBio skills
  --with-bioskills / --without-bioskills GPTomics (archived upstream)
  --with-huggingface / --without-huggingface  Focused Hugging Face skills
  --curated-only      Disable ECC; enable curated sources
  --offline          Propagate existing checkouts, no git/network fetch
  --learn            Opt in to learning dependencies and extraction
  --no-learn         No learning dependencies/extraction (default)
  --no-llm           Regex-only extraction with --learn
  --yes             Noninteractive compatibility flag; never overwrite user data
  --repair-conflicts Back up differing legacy/edited skills before replacement
  --uninstall       Remove unchanged managed skills and shell block only
  --help, -h        Show help
Fresh installs default to ECC; source choices persist. Existing checkouts and
user-created/modified skills are preserved. Python dependencies use the isolated
~/.claude/skillweave-venv. --offline still needs dependencies already available.
No harnesses, system packages or model weights are installed.
HELP
}
LEARN=false; UNINSTALL=false; NO_LLM=false; ARGS=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --with-science|--without-science|--with-curated|--without-curated|--with-bio|--without-bio|--with-bioskills|--without-bioskills|--with-huggingface|--without-huggingface|--with-ecc|--without-ecc|--offline|--repair-conflicts)
            ARGS+=("$1"); shift ;;
        --curated-only) ARGS+=(--without-ecc --with-curated); shift ;;
        --learn) LEARN=true; shift ;;
        --no-learn) LEARN=false; shift ;;
        --no-llm) NO_LLM=true; shift ;;
        --yes) shift ;;
        --uninstall) UNINSTALL=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) error "Unknown option: $1 (see --help)" ;;
    esac
done
command -v python3 >/dev/null 2>&1 || error 'Python 3 is required; install it with your package manager.'
# Only remove complete, recognized managed blocks; never source user rc files.
shell_integration() {
    python3 - "$REPO_DIR/configs/zshrc-skills-block.sh" "$1" <<'PY'
import os, re, sys
from pathlib import Path
home = Path.home()
mode = sys.argv[2]
paths = [home / name for name in ('.zshrc', '.bashrc', '.bash_profile', '.profile')]
existing = [p for p in paths if p.is_file()]
if mode == 'install' and not existing:
    shell = Path(os.environ.get('SHELL', '/bin/bash')).name
    if shell not in ('bash', 'zsh'):
        print('Shell integration skipped: only bash/zsh rc syntax is supported.')
        sys.exit(0)
    existing = [home / ('.zshrc' if shell == 'zsh' else '.bashrc')]
block = Path(sys.argv[1]).read_text() if mode == 'install' else ''
pattern = r'^# Skills Layer[^\n]*\n.*?^# End Skills Layer[^\n]*(?:\n|$)'
for path in existing:
    old = path.read_text() if path.exists() else ''
    starts = len(re.findall(r'^# Skills Layer[^\n]*$', old, re.M))
    matches = list(re.finditer(pattern, old, re.M | re.S))
    if starts != len(matches):
        raise SystemExit(f'Incomplete skills block in {path}; repair it before retrying.')
    new = re.sub(pattern, '', old, flags=re.M | re.S)
    if mode == 'install':
        new = new.rstrip('\n') + '\n\n' + block.lstrip('\n')
    if new != old:
        if path.exists():
            backup = path.with_name(path.name + '.skillweave.bak')
            if not backup.exists():
                backup.write_text(old)
        path.write_text(new)
        print(f'{mode}: {path}')
PY
}
if $UNINSTALL; then
    bash "$REPO_DIR/scripts/update-ecc.sh" --uninstall
    shell_integration uninstall
    printf 'Uninstalled managed skills/shell block. Source clones, runtime, venv, user skills and harness configuration preserved.\n'
    exit 0
fi
command -v git >/dev/null 2>&1 || error 'git is required; install it with your package manager.'
source "$REPO_DIR/scripts/bootstrap-python.sh"
skillweave_python "$REPO_DIR" "$LEARN"
bash "$REPO_DIR/scripts/update-ecc.sh" --install --no-learn "${ARGS[@]}"
# Preserve repository layout so installed updater and extractor find their helpers.
python3 - "$REPO_DIR" <<'PY'
import hashlib, json, shutil, sys
from pathlib import Path
root = Path(sys.argv[1]).resolve()
dest = Path.home() / '.claude/scripts'
files = ['safe-install.sh', 'sync-learned-skills.sh', 'extract-conversation-skills.py',
         'model_backend.py', 'requirements.txt', 'requirements-learning.txt',
         'configs/zshrc-skills-block.sh', 'scripts/bootstrap-python.sh',
         'scripts/update-ecc.sh', 'scripts/skill_sync.py', 'scripts/skill_sanitize.py',
         'scripts/skill_delivery.py', 'scripts/harness_paths.py',
         'scripts/setup-copilot-skills.sh', 'scripts/setup-omp-skills.sh',
         'scripts/verify.sh', 'scripts/verify_setup.py', 'scripts/verify-omp.sh',
         'scripts/verify_omp.py', 'scripts/install-bioskills.sh']
manifest = dest / '.skillweave-runtime.json'
owned = json.loads(manifest.read_text()) if manifest.exists() else {}
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
for name in files:
    src, target = root / name, dest / name
    if not src.is_file():
        raise SystemExit(f'Required runtime helper missing: {src}')
    if src.resolve() == target.resolve():
        continue
    if target.is_symlink():
        raise SystemExit(f'Refusing to replace symlinked runtime file: {target}')
    if target.exists() and digest(target) != digest(src) and digest(target) != owned.get(name):
        raise SystemExit(f'Existing unmanaged/edited helper preserved: {target}; back it up or move it, then retry.')
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, target)
    owned[name] = digest(target)
manifest.write_text(json.dumps(owned, indent=2) + '\n')
PY
shell_integration install
if $LEARN; then
    LEARN_ARGS=()
    if $NO_LLM; then LEARN_ARGS+=(--no-llm); fi
    bash "$REPO_DIR/sync-learned-skills.sh" "${LEARN_ARGS[@]}"
fi
printf 'Skills installed. Open a new shell to activate aliases; existing model choices were not changed.\n'
