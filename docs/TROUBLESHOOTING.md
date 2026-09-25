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

## Source updates or managed files conflict

By default, the updater never resets dirty checkouts or replaces edited/unmanaged
skills. Identical legacy copies are adopted automatically. A conflict returns
nonzero and leaves the entire affected skill unchanged, including its assets.

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

For copied sources without `.git`, `--offline` uses the snapshot. To update one,
move the reported source directory to a uniquely named backup yourself, then run
the updater online to clone its canonical upstream. Do not initialize Git over a
snapshot or force-reset it: local changes cannot otherwise be recovered.
`--no-prune` postpones ordinary removals, but explicit `--repair-conflicts` still
backs up conflicting aliases before replacing them.

bioSkills is archived. Disable it with `--without-bioskills` if you do not want
that reference snapshot.

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
For token-cost measurements and a project allowlist example, see
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

Do not inject `combined-skills.txt` as a system prompt. Reduce sources/tools
before increasing context; advertised maximum context is not available RAM.
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

## Proxy or enterprise TLS

Installation does not disable Zscaler or alter security agents/proxies. Use your
organization's approved CA/proxy settings. Local extraction bypasses proxy
variables; other harnesses may need an approved loopback `NO_PROXY` setting.
