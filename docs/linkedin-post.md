# LinkedIn Post: ai-skillweave

Most AI agent setups are stateless by default for **corrections**. Static conventions can be persisted manually (CLAUDE.md, AGENTS.md, copilot-instructions.md), but agents don't learn from your feedback across sessions. "No, use absolute paths" today doesn't change behavior tomorrow.

ai-skillweave started with ~450 skills for Claude Code. It now ships **>2,500 unique skills** from 14 open-source libraries — synced natively to Claude Code, Codex, OpenClaw, Pi, Copilot, and Hermes.

MCP servers extend what it can do: persistent memory, real-time docs lookup, browser automation, codebase context maps, sequential reasoning, token optimization, Google Docs integration, and a bioinformatics knowledge graph.

And it learns. Corrections get captured in real-time via hooks and distilled into reusable skills through a 4-stage pipeline — **batched LLM distillation runs 30-50× faster than naive per-group calls** (~580 groups in 2-5 minutes instead of 4.8 hours). You correct once — every harness remembers.

The goal isn't using six agents. It's having one harness that works with whatever agent you choose.

github.com/chazhyseni/ai-skillweave

#AI #MachineLearning #Bioinformatics #DeveloperTools #OpenSource #ClaudeCode #Codex
