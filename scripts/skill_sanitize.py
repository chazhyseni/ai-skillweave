#!/usr/bin/env python3
"""Normalize copied skill frontmatter without editing upstream or losing metadata.

Valid YAML (including block scalars, lists and harness-specific fields) is kept.
Only a leading prefix or the common unquoted-description colon error is repaired.
Ambiguous malformed input is an actionable error, never a fabricated skill.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise RuntimeError("PyYAML is required; run safe-install.sh or install requirements.txt") from exc


def _parse(content: str, path: str | Path) -> tuple[dict, str, str]:
    match = re.search(r"^---[ \t]*\r?\n(.*?)^---[ \t]*(?:\r?\n|$)", content, re.M | re.S)
    if not match:
        raise ValueError(f"{path}: missing YAML frontmatter; add name and description upstream")
    raw = match.group(1)
    try:
        data = yaml.safe_load(raw)
    except yaml.YAMLError:
        # Quote only a single-line description. Never discard unknown fields.
        repaired = re.sub(r"^description:[ \t]*(.+)$",
                          lambda m: "description: " + json.dumps(m.group(1), ensure_ascii=False),
                          raw, count=1, flags=re.M)
        try:
            data = yaml.safe_load(repaired)
        except yaml.YAMLError as exc:
            raise ValueError(f"{path}: malformed frontmatter; repair source before syncing: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError(f"{path}: frontmatter must be a mapping")
    for field in ("name", "description"):
        if not isinstance(data.get(field), str) or not data[field].strip():
            raise ValueError(f"{path}: frontmatter requires a nonempty string {field}")
    return data, content[:match.start()], content[match.end():]


def sanitize_skill_md(path: str | Path) -> str:
    """Return valid copied content, preserving full descriptions, metadata and body."""
    content = Path(path).read_text(encoding="utf-8")
    data, prefix, body = _parse(content, path)
    match = re.search(r"^---[ \t]*\r?\n(.*?)^---[ \t]*(?:\r?\n|$)", content, re.M | re.S)
    try:
        original = yaml.safe_load(match.group(1))
    except yaml.YAMLError:
        original = None
    if original == data and not prefix:
        return content
    # Keep copyright comments/prefix as body text rather than dropping them.
    header = yaml.safe_dump(data, allow_unicode=True, sort_keys=False, width=4096)
    return "---\n" + header + "---\n" + prefix + body


def needs_sanitize(path: str | Path) -> bool:
    return sanitize_skill_md(path) != Path(path).read_text(encoding="utf-8")


def needs_sanitize_for_copilot(path: str | Path) -> bool:
    return needs_sanitize(path)
