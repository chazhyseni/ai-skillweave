# Troubleshooting

## Python has no `activate`

A uv-managed interpreter is not a virtualenv. Let the installer create
`~/.claude/skillweave-venv`, or use:

```bash
uv venv --python 3.13 .venv
source .venv/bin/activate
```

Install your platform's venv/pip support if needed. Do not use `sudo pip` or
`--break-system-packages`. Learning dependencies are opt-in with `--learn`.

## pip repeats DNS warnings but installs successfully

pip checks its configured indexes, including inherited extra indexes. An
unreachable extra index can produce repeated DNS warnings even when PyPI
successfully supplies PyYAML and json5. `Successfully installed ...` means that
dependency step completed; those retries are not skill-source failures.
Subsequent installs reuse the environment when its required imports work.

Inspect your own pip configuration with `python3 -m pip config debug` and the
`PIP_INDEX_URL`/`PIP_EXTRA_INDEX_URL` environment variables. Do not paste credentials
from that output. If you do not require a private index, this one invocation uses
only public PyPI without changing global configuration:

```bash
PIP_CONFIG_FILE=/dev/null PIP_EXTRA_INDEX_URL= \
  PIP_INDEX_URL=https://pypi.org/simple bash install.sh
```

Keep organization-required indexes, certificates and proxies configured instead
of bypassing them. The installer does not suppress DNS errors or disable retries.

## Source updates or managed files conflict

Normal installation uses valid existing sources, including copied snapshots and
Git trees with local edits. It prints `LOCAL ... upstream refresh skipped` rather
than failing installation. Clean tracked sources still update normally. No local
source changes are reset or merged automatically.

Explicit `scripts/update-ecc.sh` updates remain strict: they refuse to refresh
dirty/snapshot sources unless you select offline use or backup-first recovery.
Edited/unmanaged destination skills are protected independently. Identical legacy
copies are adopted automatically; a destination conflict leaves its entire skill
unchanged, including assets, and returns nonzero.

For a legacy install with hundreds of conflicts, do not delete your skills tree.
Use the repository scripts (rather than an older installed `skills-update` alias):

```bash
# Restrict diagnosis and recovery to OMP; no source fetches.
bash scripts/setup-omp-skills.sh --repair-conflicts --dry-run
bash scripts/setup-omp-skills.sh --repair-conflicts
bash scripts/verify-omp.sh
```

Explicit repair moves each differing skill or duplicate-name legacy alias into a
unique `skillweave-backups/<skill>-<random>/<skill>/` directory beside the skills
root, then installs the selected source. **Personal additions move into that
backup too.** Nothing is discarded; backups are retained indefinitely and are
outside native discovery. To restore one, first move the new skill aside, then
move the saved directory back to its original path. The next ordinary sync will
report differing restored content rather than overwrite it.

Use `--harness NAME` with `update-ecc.sh` for other harnesses, or omit it only
when you intend recovery across all detected destinations. Review every printed
backup path. Symlink targets are not modified. Recovery does not reset source
repositories or repair malformed upstream frontmatter.

`602 managed skills` was an ownership-record count, not a native-loader success
count. The final error count covered **all sources and harnesses**. Output now
reports each harness's conflicting-skill count separately. OMP resolves the
frontmatter `name`, not the folder name; old copies with different folders but
identical declared names can shadow the selected version until alias recovery.

To replace legacy/dirty sources with current canonical upstream copies:

```bash
# Preview is read-only and uses current local payloads, not future clone contents.
bash scripts/update-ecc.sh --repair-sources --repair-conflicts --dry-run
bash install.sh --only skills --repair-sources --repair-conflicts
```

`--repair-sources` first clones upstream into a temporary sibling directory.
Only after a successful clone does it move the complete original source,
including Git history, ignored files and local edits, into
`skillweave-source-backups/<source>-<random>/<source>/` beside the source.
It then installs the fresh clone. Clone failure leaves the original in place;
promotion failure attempts to restore it. Backup paths are printed and retained.
**Local customizations stay in the backup, not in the new active source.**
This is replacement with preservation, not an automatic merge.

The source and destination recovery flags are separate. Source repair requires
online skills installation/update, not `--offline`, uninstall or a target-only
harness install. Ordinary later installs do not create another source backup
unless the source becomes modified again and explicit repair is requested.
`--no-prune` postpones ordinary removals, but explicit `--repair-conflicts` still
backs up conflicting aliases before replacing them.

bioSkills is archived. Disable it with `--without-bioskills` if you do not want
that reference snapshot.

BioNeMo publishes both authoring directories and a generated skill bundle.
Discovery now selects the published bundle once (31 unique skills in the
inspected revision), with the older layout as fallback. This avoids misleading
`bionemo overrides bionemo` messages without dropping any of those identities.

## Skills are missing after sync

```bash
bash scripts/update-ecc.sh --offline --dry-run
bash scripts/update-ecc.sh --offline
bash install.sh --verify
```

Restart/reload the harness, then inspect its skill list. Check
[the native paths](../README.md#native-harness-paths), disabled/provider settings,
and context warnings. Current Codex uses `.agents/skills`; OMP does not use Pi's
skill directory. Use `--harness NAME` to explicitly create a new target.

Set `OMP_PROFILE=research` when updating a named OMP profile. Skills, model setup,
and history extraction resolve the same active profile. The
`SKILLWEAVE_OMP_AGENT_DIR` override is strongest; launch OMP with the matching
`PI_CODING_AGENT_DIR`. Existing profiles are included when no active profile or
custom directory is selected.

Native verification runs `omp read skill://NAME:raw` for every installed skill
and compares its content. It does not invoke a model or run skill scripts.
Failures can indicate disabled discovery, project-level shadowing, or an old OMP
binary; inspect `omp --version` and the named `omp read` command. Frontmatter
`enabled: false` is reported separately. The verifier uses your installed OMP and
may initialize its configuration/cache. OMP needs the `read` tool available to
advertise skills in an agent session; `--no-tools` omits that index.

The migration code uses portable Python filesystem operations rather than GNU
`sed`/`cp` options. Linux native-loader checks do not prove macOS execution; run
the same recovery preview and native verifier on the Mac.

If you deliberately set `skills.includeSkills`/`ignoredSkills`, the full-catalog
verifier reports excluded on-disk skills as not discoverable. That is expected
filtering, not corrupt installation. Verify the unrestricted installation first,
then test the intended shortlist with `omp read skill://NAME`.
For loading behavior and an optional project allowlist example, see
[Token cost and automatic selection](../README.md#token-cost-and-automatic-selection).

Old Copilot `COPILOT_SKILLS_DIRS` exports/wrappers may cause duplicate discovery.
Review obsolete entries manually; current setup uses `.copilot/skills`. Never
delete a symlink's target while removing an old bridge.

## Local model fails or runs out of context

```bash
curl --fail http://127.0.0.1:11434/api/tags  # Ollama
curl --fail http://127.0.0.1:8080/health    # llama.cpp
curl --fail http://127.0.0.1:8080/v1/models
```

Check the exact tag/alias, server version, chat template, output limit and
context allocation. Ollama takes a root URL; llama.cpp takes `/v1`. Codex needs
Responses API support, not just chat completions. See [LOCAL-MODELS.md](LOCAL-MODELS.md).

Do not inject `combined-skills.txt` as a system prompt. Keep required libraries
available and size the model/server for the actual prompt; advertised maximum
context is not available RAM.
Empty, incomplete or truncated extraction responses are errors, not reasons to
silently send histories to the cloud.

If `ollama` fails with `_ollama_with_skills: command not found`, the current shell
still has a legacy Skillweave wrapper. Inspect `type -a ollama`, use
`command ollama list` to bypass a function/alias, and open a fresh shell after
installing the new managed shell block. Do not replace unrelated personal aliases.

If Python reports missing `yaml`, use the installed environment or the shell
wrappers (`scripts/verify-omp.sh`, `scripts/update-ecc.sh`), not a different
system interpreter. Set `SKILLWEAVE_PYTHON` explicitly for an alternate environment
containing `requirements.txt`. Model setup wrappers also prefer the installed
environment.

## MCP server or runtime helper unavailable

MCP setup skips missing executables and does not auto-enable remote templates.
Google Docs needs a separately installed/authenticated server. Use the upstream
instructions, then run `bash scripts/setup-mcp.sh` and `claude mcp list`.
A config entry does not prove a working connection. Malformed existing JSON is
preserved; repair it rather than replacing it with an empty config.

Edited/unmanaged helpers in `~/.claude/scripts` are also preserved. Compare or
back up the named file before retrying. Keep its `scripts/` and `configs/`
hierarchy intact. Scientific tools, `bip`, Beads and other skill dependencies
must be installed separately; `beads-mcp` does not install the Go `bd` CLI.

On a fresh home directory, the default installer skips Claude MCP registration
until Claude Code has created `~/.claude.json`, instead of aborting a successful
skill installation. Run Claude Code once, then `bash install.sh --only claude`.
Malformed existing configuration is still an error, not silently replaced.

## Ruflo installation

Use `bash install.sh --only ruflo`; this is opt-in, not part of the default
installation. It reuses an existing executable or installs user-local packages.
If `ruflo` is not found afterward, add `~/.local/bin` to PATH or use
`~/.local/share/ai-skillweave/ruflo/node_modules/.bin/ruflo`.
An existing launcher is never overwritten.

`--offline` requires Ruflo already installed. npm failures remain visible;
check the configured npm registry/proxy and Node version. A failed fresh install
does not receive a completion marker, so the next attempt retries package
installation instead of treating a partial prefix as complete.
No project initialization, daemon or MCP registration is performed. Review
`ruflo init --help` before deliberately modifying a project's configuration.

## Proxy or enterprise TLS

Installation does not disable Zscaler or alter security agents/proxies. Use your
organization's approved CA/proxy settings. Local extraction bypasses proxy
variables; other harnesses may need an approved loopback `NO_PROXY` setting.
