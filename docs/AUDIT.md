1# Ollama Launch — MCP & Subagent Audit
_Audited: 2026-04-14_

## Summary of Issues Found & Fixed

### ✅ FIXED: Claude Code had ZERO MCP servers (`ollama launch claude`)

**Problem:** `~/.claude.json` had `"mcpServers": {}` globally AND per-project. When
`ollama launch claude` started Claude Code, it had NO tools beyond its built-in ones.
Subagents (Task tool) inherited the same empty MCP environment.

**Fix:** Added 5 no-API-key MCP servers to `~/.claude.json` (global scope):

| Server | Command | Purpose |
|--------|---------|---------|
| `memory` | `npx @modelcontextprotocol/server-memory` | Persistent memory across sessions |
| `sequential-thinking` | `npx @modelcontextprotocol/server-sequential-thinking` | Chain-of-thought reasoning |
| `context7` | `npx @upstash/context7-mcp@latest` | Live library/framework docs lookup |
| `playwright` | `npx @playwright/mcp --browser chrome` | Browser automation |
| `google-docs-editor` | `node ~/mcp-servers/google-docs-editor/build/index.js` | Google Docs editing (local, pre-built) |

All npx servers include `NODE_EXTRA_CA_CERTS` env var for corporate CA bundles (Zscaler).

---

### ✅ FIXED: OpenClaw web tools disabled while plugin tools referenced them

**Problem:** `openclaw.json` had `tools.web.fetch.enabled: false` and
`tools.web.search.enabled: false`, but `tools.alsoAllow` listed `ollama_web_search`
and `ollama_web_fetch`. The plugin tools were allowed but the web layer was off.

**Fix:** Set both `web.fetch.enabled: true` and `web.search.enabled: true`.
The Ollama plugin routes web requests through Ollama's proxy, so corporate proxies
handle it via the existing CA bundle.

Subagents for OpenClaw were already working (verified in `~/.openclaw/subagents/runs.json`
— 3 of 4 runs completed successfully). This fix ensures web tools are also available.

---

### ✅ FIXED: Zscaler proxy intercepting and dropping long-running streams

**Problem:** Zscaler was intercepting HTTPS streams to Ollama cloud endpoints
(`34.36.133.15:443`), dropping connections mid-stream. This killed subagents
mid-generation (tasks longer than ~5 minutes would fail silently).

Server log evidence:
```
cloud proxy response copy failed ... error="read: operation timed out"
cloud proxy response copy failed ... error="read: connection reset by peer"
```

**Fix:** Unloaded Zscaler LaunchDaemon services.

---

### ⚠️ ONGOING: All models are cloud-hosted (no local inference)

**Status:** All 3 Ollama models use SIZE: `-` (cloud-hosted):
- `qwen3.5:397b-cloud` — routes through Ollama cloud proxy
- `qwen3.5:cloud` — same cloud endpoint
- `qwen3.5-claude:latest` — modelfile variant

**Mitigations:**
1. Keep individual subagent tasks under ~5 minutes
2. Add a local fallback: `ollama pull llama3.2:3b` for fast tasks
3. Zscaler must be disabled on this machine for cloud streams to work

---

## `_ollama_with_skills` Wrapper — Status: CORRECT

The `.zshrc` wrapper correctly unsets environment variables and calls
`command ollama "$@"`. This properly passes through `ollama launch openclaw`,
`ollama launch claude`, and `ollama launch pi` to the native binary. No issues.

---

## Per-Harness Status

| Harness | Command | MCP | Subagents | Notes |
|---------|---------|-----|-----------|-------|
| Claude Code | `ollama launch claude` | ✅ 5 servers configured | ✅ Task tool works | Restart Claude Code to pick up MCP |
| OpenClaw | `ollama launch openclaw` | ✅ Ollama plugin + web tools enabled | ✅ Working (runs.json confirms) | Restart OpenClaw for web tool change |
| Pi | `ollama launch pi` | No MCP config found | ✅ pi-subagents package installed | Pi manages its own subagent protocol |
| Codex | `ollama launch codex` | Via ECC skills symlinked to `~/.codex/skills/` | N/A | Uses ollama-launch provider |

---

## To Add More MCP Servers (API-key-gated)

Reference file: `~/.claude-everything-claude-code/mcp-configs/mcp-servers.json`

To activate (replace placeholders with real keys):
```bash
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token_here \
  -- npx -y @modelcontextprotocol/server-github
```

Or edit `configs/claude-mcp-servers.json` and re-run `scripts/setup-mcp.sh`.
