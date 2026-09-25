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

The updater never resets dirty checkouts or replaces edited/unmanaged skills.
A conflict returns nonzero: compare the named files, preserve your changes,
then merge or move them aside deliberately before retrying.

For old copied sources without `.git`, `--offline` continues delivering the
snapshot. Back up/move the reported checkout before recloning. Old name-only
manifests cannot prove file ownership; migration preserves ambiguous copies.
`--no-prune` postpones removal while retaining ownership for a later run.

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

Set `SKILLWEAVE_OMP_AGENT_DIR` for a custom OMP agent directory, and align custom
OpenClaw workspaces manually. OMP needs the `read` tool available to advertise
skills; `--no-tools` omits its skill index. Filesystem diagnostics alone do not
prove runtime discovery or invocation.

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
