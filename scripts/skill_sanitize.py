#!/usr/bin/env python3
"""
skill_sanitize.py — Shared YAML frontmatter sanitizer for SKILL.md files.

Used by update-ecc.sh (Codex/OpenClaw/Pi) and setup-copilot-skills.sh
(GitHub Copilot CLI) to normalize frontmatter before a harness loads it.

Why this exists:
  Different skill loaders tolerate different YAML subsets.
  - Claude Code / Hermes: lenient — accepts most YAML 1.2.
  - GitHub Copilot CLI 1.0.65: rejects any frontmatter that its bundled
    `yaml` v2 parser (in the prebuilds/<platform>/runtime.node addon)
    can't deserialize. Its `promptsParseFrontmatter()` returns
    `ok: false, errorMessage: "missing or malformed YAML frontmatter"` or
    `failed to parse YAML frontmatter: ...` for any of these:
      * No `---\n...\n---` block at all
      * Block-scalar descriptions (`description: |` / `>`)
      * Unquoted descriptions containing `key: value` patterns mid-string
        (e.g. URLs with `?key=val`, code samples, `QC: getSex sex ...`)
      * Control characters / non-printable bytes in description
      * Unbalanced quotes or other malformed YAML
  - Codex, OpenClaw, Pi: strictest — reject extra top-level fields and
    nested mappings indented under non-block fields.

Detection: this module parses frontmatter with PyYAML 6.x (`yaml.safe_load`).
If the parse raises (or the parsed `description` is not a string), the file
is marked as needing sanitization. Sanitization re-emits a strict-YAML
frontmatter with `description` always wrapped in `"..."` and other fields
preserved as scalars or simple maps.

Designed to be sourced from bash via `python3 -c "import sys;
sys.path.insert(0, '...'); from skill_sanitize import ..."` so we have a
single source of truth for the sanitization rules.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml  # PyYAML ≥ 6.x
except ImportError:
    # Try the system dist-packages path on Debian/Ubuntu
    sys.path.insert(0, "/usr/lib/python3/dist-packages")
    try:
        import yaml  # type: ignore[no-redef]
    except ImportError:
        yaml = None  # type: ignore[assignment]


# Fields that survive sanitization. Anything else is stripped.
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
# silently past this point; staying under it keeps the description fully
# visible in skill pickers.
DESCRIPTION_MAX_LEN = 200

# All top-level scalars (strings, numbers, booleans) can be round-tripped
# verbatim. Lists and maps survive only if they are simple (no anchors,
# no flow style). For nested maps we emit them as a small JSON-ish block —
# Copilot's addon, like PyYAML, accepts them as long as indentation is sane.


def _strip_leading_html_comments(text: str) -> str:
    """Strip leading whitespace and any `<!-- ... -->` HTML comment
    blocks that precede the frontmatter.

    Several upstream skill sources (MAGE from BioGrid, medical-skills
    variants, etc.) wrap their frontmatter region in an HTML comment
    that contains a copyright/license notice. GitHub Copilot CLI's
    `promptsParseFrontmatter` scans from byte 0 for the first `---`
    delimiter and rejects any leading whitespace or comment prefix
    (unlike PyYAML which gracefully strips them). Files affected get
    `frontmatterJson: "{}"` with "missing or malformed YAML frontmatter".

    Two classes of prefix are stripped:
      1. Leading whitespace (newlines, spaces, tabs) before `---`.
      2. `<!-- ... -->` HTML comment blocks before `---`, plus the
         whitespace between `-->` and `---`.

    Only leading comments are stripped — comments inside the body are
    preserved verbatim.
    """
    out = text
    # Strip leading HTML comments in a loop (in case multiple are stacked).
    while True:
        m = re.match(r"\s*<!--", out)
        if not m:
            break
        end = out.find("-->", m.end())
        if end == -1:
            break
        rest = out[end + 3:]
        fm = re.search(r"^---\s*\n", rest, re.MULTILINE)
        if fm:
            out = rest[fm.start():]
        else:
            out = ""
    # After comment stripping (or when no comment was present), also
    # strip any leading whitespace so the frontmatter `---` sits at
    # byte 0 — Copilot's parser requires it.
    out = re.sub(r"^\s+", "", out, count=1)
    return out


def _frontmatter_split(text: str) -> tuple[str, str] | None:
    """Return (frontmatter_yaml, body) or None if no frontmatter block.

    A SKILL.md with no frontmatter is rejected by Copilot CLI as
    "missing or malformed YAML frontmatter". We don't synthesize one
    here — the caller decides whether to skip or patch.

    Search the whole file for a `---\n...\n---\n` block. Some upstream
    skill sources (notably MAGE from BioGrid) wrap the frontmatter in
    an HTML comment (`<!-- ... -->`) so it doesn't start at offset 0.
    We strip leading HTML comments first.
    """
    text = _strip_leading_html_comments(text)
    # Common case: frontmatter is at the very top.
    if text.startswith("---"):
        parts = text.split("---", 2)
        if len(parts) >= 3:
            fm_raw = parts[1]
            body = parts[2]
            if _looks_like_frontmatter(fm_raw):
                return fm_raw, body
    # Fallback: scan for the first `---\n...\n---\n` block anywhere.
    m = re.search(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL | re.MULTILINE)
    if m:
        return m.group(1), text[m.end():]
    return None


def _looks_like_frontmatter(fm_text: str) -> bool:
    """Quick heuristic: does this block look like YAML frontmatter (i.e.
    contains at least one `key: value` line at column 0)?"""
    for line in fm_text.splitlines():
        if re.match(r"^[a-zA-Z_][a-zA-Z0-9_-]*:\s", line):
            return True
    return False


def _yaml_parse(text: str) -> Any:
    if yaml is None:
        raise RuntimeError("PyYAML not available; cannot parse frontmatter")
    return yaml.safe_load(text)


def _yaml_dump(obj: Any) -> str:
    if yaml is None:
        raise RuntimeError("PyYAML not available; cannot dump frontmatter")
    return yaml.safe_dump(
        obj,
        default_flow_style=False,
        allow_unicode=True,
        sort_keys=False,
        width=4096,
    )


def _parseable(fm_text: str) -> bool:
    """Return True iff PyYAML can parse the frontmatter cleanly and the
    resulting mapping has a string `description` (if present)."""
    if yaml is None:
        return False
    try:
        obj = _yaml_parse(fm_text)
    except Exception:
        return False
    if not isinstance(obj, dict):
        # YAML parses to a scalar or list — not a valid frontmatter block.
        return False
    if "description" in obj and not isinstance(obj["description"], str):
        # YAML parser mis-parsed the description (e.g. as a dict because of
        # embedded `: ` mid-string). The file is broken for Copilot.
        return False
    return True


def needs_sanitize(path: str | Path) -> bool:
    """Strict predicate: True if the file has any feature that strict
    YAML parsers (Copilot CLI, Codex, OpenClaw, Pi) would reject.

    Detects:
      - No frontmatter at all
      - Frontmatter that doesn't parse via PyYAML
      - Description parsed as non-string (nested mapping)
      - Top-level fields outside ALLOWED_FIELDS
    """
    content = Path(path).read_text(errors="replace")
    split = _frontmatter_split(content)
    if split is None:
        return True
    fm_raw, _ = split
    if not _parseable(fm_raw):
        return True
    try:
        obj = _yaml_parse(fm_raw)
    except Exception:
        return True
    if not isinstance(obj, dict):
        return True
    fields = set(obj.keys())
    if fields - ALLOWED_FIELDS:
        return True
    return False


def needs_sanitize_for_copilot(path: str | Path) -> bool:
    """Predicate specific to Copilot CLI: True iff the file would be
    rejected by `promptsParseFrontmatter` in @github/copilot's bundled
    runtime addon.

    Currently this is the same as `needs_sanitize` because Copilot is
    strict about both YAML parse errors and extra fields — but kept as
    a separate function so the policy can diverge later without
    touching every call site.
    """
    if needs_sanitize(path):
        return True
    try:
        content = Path(path).read_text(errors="replace")
    except Exception:
        return False
    # Copilot's bundled `yaml` v2 parser requires the frontmatter
    # `---` delimiter to appear at byte 0 (no leading whitespace or
    # HTML comment). PyYAML is permissive about both. Flag files that
    # have *any* leading whitespace or `<!-- ... -->` before `---` so
    # the sanitizer rewrites them with `---` at byte 0. We check only
    # the first byte — anything after is handled by the regular
    # `needs_sanitize` path.
    if content and content[0] in " \t\r\n":
        return True
    if re.match(r"\s*<!--", content):
        return True
    return False


def _escape_for_double_quoted_yaml(s: str) -> str:
    """Escape a string so it can be wrapped in `"..."` and survive both
    YAML 1.2 parsing and JSON.parse round-trip (which Copilot's addon
    does internally — see `frontmatterJson` in app.js $ve())."""
    if s is None:
        return ""
    # Normalize whitespace: collapse all runs of whitespace (including \n, \r, \t)
    # into single spaces. This kills any line-breaks that would otherwise
    # break the "single-line" YAML assumption.
    s = re.sub(r"\s+", " ", s, flags=re.UNICODE).strip()
    # Strip ASCII control chars except space (already handled above).
    s = "".join(ch for ch in s if ch == "\t" or ch >= " ")
    # Escape backslashes and double-quotes for YAML double-quoted scalar.
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    # Truncate to keep skill pickers showing the full description.
    if len(s) > DESCRIPTION_MAX_LEN:
        s = s[:DESCRIPTION_MAX_LEN].rstrip()
    return s


def _sanitize_description(raw: str) -> str:
    """Take a raw description value (whatever form it was in) and return
    a clean single-line description that parses as YAML."""
    return _escape_for_double_quoted_yaml(raw)


def _yaml_emit_value(obj: Any, indent: int = 0) -> str:
    """Emit a Python object as a YAML scalar or block, suitable for
    inclusion in a top-level frontmatter block. Used for non-description
    fields which we want to preserve as-is when possible."""
    if isinstance(obj, str):
        # Always emit strings as double-quoted YAML scalars so embedded
        # `: ` characters don't accidentally parse as nested mappings.
        return '"' + _escape_for_double_quoted_yaml(obj) + '"'
    if isinstance(obj, bool):
        return "true" if obj else "false"
    if isinstance(obj, (int, float)):
        return str(obj)
    if obj is None:
        return "null"
    if isinstance(obj, list):
        # Block style for lists containing dicts (so each dict's keys
        # can be properly nested under the `- ` marker). Flow style
        # only for short scalar-only lists.
        if (all(isinstance(x, (str, int, float, bool)) for x in obj)
                and len(obj) <= 8):
            items = []
            for x in obj:
                if isinstance(x, str):
                    items.append('"' + _escape_for_double_quoted_yaml(x) + '"')
                else:
                    items.append(str(x))
            return "[" + ", ".join(items) + "]"
        # Block style. Layout for a list of dicts:
        #   parent_key:
        #     - key1: val1
        #       key2: val2
        #     - key3: val3
        # `- ` marker is at column `indent`, so the first key after it
        # must start at column `indent + 2`. The first line is always
        # `- <first key>: <value>` — we emit a trailing `\n` so the
        # caller (the dict emitter) sees `\n` in the child and writes
        # the list on its own line below the parent key.
        cont_col = indent + 2
        lines = []
        for x in obj:
            child = _yaml_emit_value(x, cont_col)
            child_lines = child.split("\n")
            first = child_lines[0]
            lines.append(" " * indent + "- " + first.lstrip(" "))
            for cl in child_lines[1:]:
                lines.append(cl)
        # Append a trailing newline so callers using `if "\n" in child:`
        # detect multi-line form and write the list on its own block line.
        return "\n".join(lines) + "\n"
    if isinstance(obj, dict):
        # Emit as a nested block. Caller places key on its own line.
        # Nested dict children sit at parent_indent + 2.
        # Empty dict emits as `{}`.
        if not obj:
            return "{}"
        # Use flow style {k1: v1, k2: v2} when all values are scalars
        # or simple lists of scalars — produces cleaner output and
        # avoids indentation conflicts when this dict is itself nested
        # inside a list of dicts.
        if all(isinstance(v, (str, int, float, bool)) or v is None
               or (isinstance(v, list)
                   and all(isinstance(x, (str, int, float, bool)) for x in v))
               for v in obj.values()):
            parts = []
            for k, v in obj.items():
                if not re.match(r"^[a-zA-Z_][a-zA-Z0-9_-]*$", str(k)):
                    key = '"' + str(k).replace("\\", "\\\\").replace('"', '\\"') + '"'
                else:
                    key = str(k)
                if isinstance(v, str):
                    val = '"' + _escape_for_double_quoted_yaml(v) + '"'
                elif v is None:
                    val = "null"
                elif isinstance(v, bool):
                    val = "true" if v else "false"
                else:
                    val = str(v)
                parts.append(f"{key}: {val}")
            return "{" + ", ".join(parts) + "}"
        # Block style for dicts with nested dicts/lists.
        lines = []
        child_indent = indent + 2
        pad = " " * child_indent
        for k, v in obj.items():
            if not re.match(r"^[a-zA-Z_][a-zA-Z0-9_-]*$", str(k)):
                key = '"' + str(k).replace("\\", "\\\\").replace('"', '\\"') + '"'
            else:
                key = str(k)
            child = _yaml_emit_value(v, child_indent)
            if "\n" in child:
                lines.append(f"{pad}{key}:")
                lines.append(child)
            else:
                lines.append(f"{pad}{key}: {child}")
        # Always multi-line so the caller detects block form even for
        # single-key dicts (e.g. `metadata: {origin: ECC}`). We emit
        # with a leading "\n" so after the caller's `lstrip("\n")` the
        # first child line still has the proper indent.
        return "\n" + "\n".join(lines)
    # Fallback: emit as a quoted string repr.
    return '"' + _escape_for_double_quoted_yaml(str(obj)) + '"'


def sanitize_skill_md(path: str | Path) -> str:
    """Return sanitized SKILL.md content with a YAML 1.2 frontmatter that
    GitHub Copilot CLI's `promptsParseFrontmatter` accepts (and that
    PyYAML can round-trip cleanly).

    Strategy:
      1. Locate the `---\\n...\\n---\\n` block (may be mid-file if wrapped in HTML).
      2. Re-parse the inside with PyYAML. If it fails, fall back to a
         minimal block synthesized from raw top-of-file content.
      3. Keep only fields in ALLOWED_FIELDS.
      4. Re-emit each field via `_yaml_emit_value` (always-quoted strings).
      5. Verify the result round-trips through PyYAML. If not, raise — the
         caller should not write the bad version to disk.
    """
    content = Path(path).read_text(errors="replace")

    # Find the byte range of the `---\n...\n---\n` block so we can preserve
    # any prefix (e.g. HTML comments that wrap the frontmatter).
    # For Copilot compatibility we strip leading `<!-- ... -->` HTML
    # comment blocks from the prefix before writing back, since Copilot's
    # `promptsParseFrontmatter` scans from byte 0 and treats the comment
    # as part of the frontmatter (returns frontmatterJson: "{}" with
    # "missing or malformed YAML frontmatter").
    fm_match = re.search(r"^---\s*\n", content, re.MULTILINE)
    if not fm_match:
        return _synthesize_from_raw(content)
    block_start = fm_match.start()
    end_match = re.search(r"\n---\s*\n", content[fm_match.end():], re.MULTILINE)
    if not end_match:
        return _synthesize_from_raw(content)
    fm_raw = content[fm_match.end():fm_match.end() + end_match.start()]
    body_start = fm_match.end() + end_match.end()
    prefix_raw = content[:block_start]
    body = content[body_start:]
    prefix = _strip_leading_html_comments(prefix_raw)
    # If parsing the frontmatter as YAML doesn't yield a mapping, fall back.
    parsed: dict[str, Any] | None = None
    if yaml is not None:
        try:
            obj = _yaml_parse(fm_raw)
            if isinstance(obj, dict):
                parsed = obj
        except Exception:
            parsed = None
    if parsed is None:
        return _synthesize_from_raw(content)

    # Restrict to allowed fields, in declaration order.
    new_lines: list[str] = []
    for k, v in parsed.items():
        if k not in ALLOWED_FIELDS:
            continue
        if k == "description":
            desc_raw = v if isinstance(v, str) else str(v)
            desc_clean = _sanitize_description(desc_raw)
            new_lines.append('description: "' + desc_clean + '"')
        else:
            emitted = _yaml_emit_value(v, indent=0)
            # Use block form whenever the emitted value is multi-line.
            # Multi-line here means: contains `\n` anywhere, OR starts
            # with a list marker (`- `) which signals a block-style list.
            emitted_stripped = emitted.lstrip("\n")
            is_block = ("\n" in emitted_stripped
                        or re.match(r"^\s*- ", emitted_stripped) is not None)
            if is_block:
                new_lines.append(f"{k}:")
                new_lines.append(emitted_stripped)
            else:
                new_lines.append(f"{k}: {emitted_stripped}")

    new_fm = "\n".join(new_lines)
    rebuilt = prefix + "---\n" + new_fm + "\n---\n" + body.lstrip("\n")

    # Verify round-trip. If this fails, the sanitizer is buggy — surface
    # the failure rather than silently writing broken YAML.
    if yaml is not None:
        try:
            test_parts = rebuilt.split("---", 2)
            _yaml_parse(test_parts[1])
        except Exception as e:
            raise RuntimeError(
                f"sanitize_skill_md produced invalid YAML for {path}: {e}\n"
                f"--- begin rebuilt frontmatter ---\n{new_fm}\n--- end ---"
            )
    return rebuilt


def _extract_raw_fields(content: str) -> dict[str, str]:
    """Pull simple `name:` and `description:` values out of raw text by
    regex. Used when PyYAML fails to parse the frontmatter (e.g. an
    unquoted description contains a colon mid-string). Tries the first
    frontmatter block first, then falls back to scanning the whole file.
    """
    out: dict[str, str] = {}

    # Try the first `---\n...\n---\n` block.
    m = re.search(r"^---\s*\n(.*?)\n---\s*\n", content, re.DOTALL | re.MULTILINE)
    block_text = m.group(1) if m else content

    # `name:` is usually a simple string on its own line.
    nm = re.search(r"^name:\s*(.+?)\s*$", block_text, re.MULTILINE)
    if nm:
        out["name"] = nm.group(1).strip().strip("'\"")

    # `description:` is the tricky one. It may be quoted, block-scalar,
    # or run all the way to the next field. Strategy: capture everything
    # from `description:` until the next `^[a-z_]+:` line or end-of-block.
    dm = re.search(r"^description:\s*(.*?)(?=^\S[a-z_][a-z0-9_-]*:|\Z)",
                   block_text, re.DOTALL | re.MULTILINE)
    if dm:
        raw = dm.group(1).strip()
        # Strip block-scalar markers, drop indented continuation lines.
        if raw in ("|", ">", "|-", ">-", "|+", ">+", "|"):
            raw = ""
        else:
            # Drop leading quote if present, trailing quote too.
            raw = raw.strip().strip("'\"")
            # Unescape YAML double-quoted scalar escapes so we don't
            # double-escape on the next sanitization pass. This is the
            # fix for the "backslash doubling" infinite loop: each run
            # of sanitize_skill_md → _synthesize_from_raw → _extract_raw_fields
            # would extract the already-escaped string, then _escape_for
            # _double_quoted_yaml would escape it again, doubling all
            # backslashes. After N runs the description is all backslashes.
            raw = raw.replace("\\\\", "\\").replace('\\"', '"')
        out["description"] = raw
    return out


def _synthesize_from_raw(content: str) -> str:
    """Best-effort fallback when the input has no parseable frontmatter
    block. Extract `name` and `description` via regex from the broken
    block (or from a `# Heading` line if absent), drop any existing
    `---...---` blocks, and write a clean replacement at the top.

    This is for files where the frontmatter exists but YAML parsing fails
    (e.g. embedded `: ` in unquoted descriptions, or the block is wrapped
    in an HTML comment and Copilot's strict loader can't see it).
    """
    fields = _extract_raw_fields(content)

    # Strip only the FIRST `---\n...\n---\n` block (the actual frontmatter).
    # Using count=1 is critical: markdown bodies often contain `---` as
    # horizontal rules, and the non-greedy `.*?` with re.DOTALL would match
    # every `---...---` pair in the file, destroying body content.
    cleaned_body = re.sub(r"^---\s*\n.*?\n---\s*\n",
                          "", content, count=1,
                          flags=re.DOTALL | re.MULTILINE)
    # Also strip HTML comment wrappers (MAGE files wrap frontmatter in `<!-- -->`).
    cleaned_body = re.sub(r"<!--.*?-->", "", cleaned_body, flags=re.DOTALL)
    # Collapse runs of blank lines left behind.
    cleaned_body = re.sub(r"\n{3,}", "\n\n", cleaned_body).lstrip("\n")

    name = fields.get("name", "").strip()
    if not name:
        # Try first `# Heading` line.
        h = re.search(r"^#\s+(.+)$", cleaned_body, re.MULTILINE)
        if h:
            name = h.group(1).strip().lower().replace(" ", "-")[:64]
    if not name:
        name = "skill"
    description = fields.get("description", "").strip()
    if not description:
        # First non-blank, non-heading line.
        for line in cleaned_body.splitlines():
            stripped = line.strip()
            if stripped and not stripped.startswith("#"):
                description = stripped
                break
    if not description:
        description = name
    description = _sanitize_description(description)

    return (
        "---\n"
        f'name: "{_escape_for_double_quoted_yaml(name)}"\n'
        f'description: "{description}"\n'
        "---\n"
        + cleaned_body
    )


def sanitize_in_place(path: str | Path) -> bool:
    """Sanitize SKILL.md at `path` in place. Returns True if the file
    was modified, False if no sanitization was needed."""
    if not needs_sanitize(path):
        return False
    sanitized = sanitize_skill_md(path)
    Path(path).write_text(sanitized)
    return True
