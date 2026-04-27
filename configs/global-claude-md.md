# Global Instructions

## Output Style
- Be concise. No summaries of what you just did — the user can see the diff.
- No trailing recaps, status tables, or "here's what happened" blocks unless asked.
- When editing files, show the change, not a paragraph explaining the change.
- Prefer 1-2 sentences over bullet lists. Skip pleasantries.

## MCP Tool Usage — USE THESE PROACTIVELY

You have MCP servers available. Use them INSTEAD of raw built-in tools when applicable:

### codesight (USE FIRST when exploring any repo)
- BEFORE using Grep/Glob/Read to explore a codebase, call `codesight_get_summary` or `codesight_scan` to get a compact map of routes, schema, components, and dependencies.
- Use `codesight_get_routes` instead of grepping for API endpoints.
- Use `codesight_get_schema` instead of reading model files one by one.
- Use `codesight_get_hot_files` to find high-impact files before exploring.
- This saves tokens: one codesight call (~500 tokens) replaces 10+ file reads (~5000+ tokens).

### token-optimizer (USE for large contexts)
- When context is growing large (long conversations, many file reads), use `optimize_session` or `compress_text` to reduce token usage.
- Use `smart_read` instead of raw Read for large files — it returns only the relevant parts.
- Use `smart_grep` instead of raw Grep — it deduplicates and compresses results.
- Use `smart_diff` instead of raw git diff — it summarizes changes compactly.

### context7 (USE for library/framework questions)
- When the user asks about ANY library, framework, or API, call `resolve-library-id` then `query-docs` BEFORE answering from training data.
- Your training data may be outdated. Context7 has current docs.

### exa-web-search (USE for current information)
- When the user asks about anything that may have changed since your training cutoff, search first.

### memory (USE for cross-session continuity)
- Save important context that should persist across conversations.

### sequential-thinking (USE for complex reasoning)
- For multi-step problems, architecture decisions, or debugging — use this to structure your thinking.

## Token Discipline
- Do NOT read entire files when you only need a few lines. Use line ranges.
- Do NOT re-read files you just edited — the harness tracks file state.
- Do NOT run exploratory commands (find, ls -R, cat) when codesight or smart_read can answer faster.
- Prefer targeted Grep over broad file scanning.
- When multiple independent searches are needed, run them in parallel (single message, multiple tool calls).

## Beads Workflow (work item tracking)
If `bd` (beads) is available, use it for work item tracking across sessions:
- `bd prime` — get AI-optimised project context at session start (run this first in any project)
- `bd ready` — list open work items
- `bd create "Title" -p 2` — create a work item (priority: 1=high, 2=medium, 3=low)
- `bd update <id> --claim` — claim a work item before starting
- `bd close <id>` — close a completed item
Run `bd prime` at the start of a session when working in a repo with a `.beads/` directory.
