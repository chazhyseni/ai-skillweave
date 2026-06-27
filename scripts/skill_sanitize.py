#!/usr/bin/env python3
"""
skill_sanitize.py — Shared YAML frontmatter sanitizer for SKILL.md files.

Used by update-ecc.sh (Codex/OpenClaw/Pi) and setup-copilot-skills.sh
(GitHub Copilot CLI) to normalize frontmatter before a harness loads it.

Why this exists:
  Different skill loaders tolerate different YAML subsets.
  - Claude Code / Hermes: lenient — accepts `description: |` block scalars
    and most top-level fields without complaint.
  - GitHub Copilot CLI: stricter — rejects block-scalar descriptions
    outright (its frontmatter parser is line-oriented, not full YAML 1.2).
    Reports "missing or malformed YAML frontmatter" for every such skill.
  - Codex, OpenClaw, Pi: strictest — reject extra top-level fields and
    nested mappings indented under allowed fields.

This module flattens block scalars to single-line quoted strings, strips
extra top-level fields outside ALLOWED_FIELDS, and removes indented
continuation lines that would otherwise parse as nested YAML.

Designed to be sourced from bash via `python3 -c "import sys; sys.path.insert(0, '...'); from skill_sanitize import ..."`
so we have a single source of truth for the sanitization rules.
"""
from __future__ import annotations

import re
from pathlib import Path

# Fields that survive sanitization. Anything else is stripped (along with
# any indented continuation lines belonging to that field).
ALLOWED_FIELDS = {
    "name",
    "description",
    "origin",
    "tools",
    "license",
    "allowed-tools",
    "metadata",
    "compatibility",
}

# Maximum length for a flattened description. Some harnesses truncate
# silently past this point; staying under it keeps the description
# fully visible in skill pickers.
DESCRIPTION_MAX_LEN = 200


def sanitize_skill_md(path: str | Path) -> str:
    """Return sanitized SKILL.md content.

    Strips top-level fields not in ALLOWED_FIELDS, flattens block-scalar
    descriptions (`|` and `>`) into single-line quoted strings, and removes
    indented continuation lines (which are invalid YAML under non-block
    fields but were tolerated by Claude's lenient parser).

    The output is a strict subset of YAML 1.2 that all five harnesses
    (Claude Code, Codex, OpenClaw, Pi, GitHub Copilot CLI) accept.
    """
    content = Path(path).read_text(errors="replace")

    parts = content.split("---", 2)
    if len(parts) < 3:
        return content  # no frontmatter, return as-is

    fm_raw = parts[1]
    body = parts[2]

    new_fm_lines: list[str] = []
    lines = fm_raw.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]

        # Skip indented lines — these are nested YAML under the previous
        # field (e.g. "  author: evos" under "origin: ECC") which is
        # invalid YAML for strict parsers.
        if line and (line[0] == " " or line[0] == "\t"):
            i += 1
            continue

        m = re.match(r"^([a-z_][a-z0-9_-]*):\s*(.*)", line)
        if m:
            field, value = m.group(1), m.group(2).strip()

            if field not in ALLOWED_FIELDS:
                # Skip extra fields and any indented continuations
                i += 1
                while (
                    i < len(lines)
                    and lines[i]
                    and (lines[i][0] == " " or lines[i][0] == "\t")
                ):
                    i += 1
                continue

            if field == "description" and value in (">", ">-", "|", "|-", ">|", ""):
                # Collect block scalar lines
                block_lines: list[str] = []
                i += 1
                while (
                    i < len(lines)
                    and lines[i]
                    and (lines[i][0] == " " or lines[i][0] == "\t")
                ):
                    block_lines.append(lines[i].strip())
                    i += 1
                desc = " ".join(block_lines).strip()
                desc = desc[:DESCRIPTION_MAX_LEN].replace('"', "'")
                new_fm_lines.append(f'description: "{desc}"')
                continue

            if field == "description" and "\n" in value:
                # Multi-line inline description with continuation on next line
                desc = value.split("\n")[0].strip()[:DESCRIPTION_MAX_LEN].replace('"', "'")
                new_fm_lines.append(f'description: "{desc}"')
                i += 1
                continue

        new_fm_lines.append(line)
        i += 1

    return "---\n" + "\n".join(new_fm_lines) + "\n---" + body


def needs_sanitize(path: str | Path) -> bool:
    """Return True if SKILL.md at `path` has any feature that strict
    YAML parsers (Copilot CLI, Codex, OpenClaw, Pi) would reject:
      - Block-scalar descriptions (`description: |` / `description: >`)
      - Top-level fields outside ALLOWED_FIELDS
      - Indented lines that look like nested YAML mappings
      - Multi-line inline descriptions with continuation on next line
    """
    content = Path(path).read_text(errors="replace")
    parts = content.split("---", 2)
    if len(parts) < 3:
        return False

    fm = parts[1]

    # Block scalar descriptions — rejected by all strict parsers
    if re.search(r"^description:\s*[|>]", fm, re.MULTILINE):
        return True

    # Extra top-level fields (beyond what's allowed in target harness)
    fields = re.findall(r"^([a-z_][a-z0-9_-]*):", fm, re.MULTILINE)
    if set(fields) - ALLOWED_FIELDS:
        return True

    # Indented lines that look like nested YAML mappings (e.g. "  author: evos")
    if re.search(r"^[ \t]+[a-z_]+:", fm, re.MULTILINE):
        return True

    # Description with continuation on next line
    # (e.g. "description: foo\n  tags: bar")
    if re.search(r"^description:.*\n\s+\S+:", fm, re.MULTILINE):
        return True

    return False


def needs_sanitize_for_copilot(path: str | Path) -> bool:
    """Tighter predicate: return True ONLY if Copilot CLI will reject
    the file. Copilot's frontmatter parser is line-oriented and only
    chokes on block-scalar descriptions. Extra fields, multi-line
    inline descriptions, and indented mappings are tolerated.

    Use this when generating a sanitized tree for `~/.copilot/...`.
    """
    content = Path(path).read_text(errors="replace")
    parts = content.split("---", 2)
    if len(parts) < 3:
        return False
    fm = parts[1]
    return bool(re.search(r"^description:\s*[|>]", fm, re.MULTILINE))


def sanitize_in_place(path: str | Path) -> bool:
    """Sanitize SKILL.md at `path` in place. Returns True if the file
    was modified, False if no sanitization was needed."""
    if not needs_sanitize(path):
        return False
    sanitized = sanitize_skill_md(path)
    Path(path).write_text(sanitized)
    return True
