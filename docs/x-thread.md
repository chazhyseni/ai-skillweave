# X/Twitter Thread: ai-skillweave

## Post 1 (Main)
Most AI agent setups are stateless by default. Without configuration, they don't retain your corrections, domain expertise, or custom conventions across sessions.

ai-skillweave changes that: one install loads ~450 skills + MCP servers into Claude Code, Codex, OpenClaw, Pi, and Copilot CLI. Structured expertise, not guesswork.

And it learns from your corrections automatically.

github.com/chazhyseni/ai-s…

---

## Post 2 (What skills actually do)
These aren't vague prompts.

Each skill is a structured SKILL.md with:
• Condition — when to apply it
• Strategy — what to do
• Anti-pattern — what to avoid
• Example — concrete code

The agent knows your conventions before you type.

---

## Post 3 (MCP servers)
MCP servers extend what the agent can *do*:

• memory — persists context across sessions
• codesight — structured codebase maps (no more grep burn)
• context7 — real-time docs, not training cutoff
• sequential-thinking — decomposes complex problems
• browser automation, token optimization, and more

---

## Post 4 (Auto-learning)
The learning pipeline captures corrections via hooks and distills them into reusable skills with semantic clustering.

You correct once. Every harness remembers.

The goal: one harness, any agent.

---

## Post 5 (Call to action)
```bash
git clone https://github.com/chazhyseni/ai-skillweave
cd ai-skillweave
./install.sh
```

One command. Five harnesses. ~450 skills. MCP servers included. Zero config drift.

#AI #ML #DevTools #OpenSource
