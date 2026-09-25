#!/usr/bin/env python3
"""Read-only installation audit; no installers, configuration edits, or model pulls."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import urllib.error
import urllib.request

import yaml

from skill_sync import SOURCES, harness_roots, load_json
from skill_delivery import actual_file, safe_relative
from skill_sanitize import sanitize_skill_md


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-url", help="optionally GET an explicitly selected local model endpoint, e.g. http://127.0.0.1:8080/v1/models")
    parser.add_argument("--fix", action="store_true", help="removed: verification never runs installers")
    args = parser.parse_args()
    if args.fix:
        parser.error("--fix is no longer supported; inspect findings and run the named setup command explicitly")
    home = Path.home()
    failures = 0
    print("Harness executables (optional unless you use that harness)")
    for command in ("claude", "codex", "openclaw", "pi", "copilot", "hermes", "omp", "ollama", "llama-server"):
        print(f"  {command}: {shutil.which(command) or 'not installed'}")
    print("\nConfiguration syntax (existing files only; runtime authorization is not tested)")
    config_paths = [home / path for path in (
        ".claude.json", ".claude/settings.json", ".copilot/mcp-config.json",
        ".openclaw/openclaw.json", ".pi/agent/settings.json", ".pi/agent/models.json",
        ".codex/config.toml", ".hermes/config.yaml", ".omp/agent/settings.json",
        ".omp/agent/settings.yml", ".omp/agent/models.yml", ".omp/agent/models.yaml",
    )]
    codex_dir = Path(os.environ.get("CODEX_HOME", home / ".codex"))
    config_paths.extend(sorted(codex_dir.glob("*.config.toml")))
    for skills_root in harness_roots(home)["omp"]:
        config_paths.extend(skills_root.parent / name for name in
                            ("config.yml", "models.yml", "models.yaml"))
    config_paths = list(dict.fromkeys(config_paths))
    for path in config_paths:
        if not path.is_file():
            continue
        try:
            if path.suffix == ".toml":
                try:
                    import tomllib
                except ImportError:
                    print(f"  NOTE {path}: TOML audit requires Python 3.11+")
                    continue
                data = tomllib.loads(path.read_text())
            elif path.suffix in (".yml", ".yaml"):
                data = yaml.safe_load(path.read_text())
            else:
                try:
                    data = json.loads(path.read_text())
                except ValueError:
                    if path.name != "openclaw.json":
                        raise
                    import json5
                    data = json5.loads(path.read_text())
            if not isinstance(data, dict):
                raise ValueError("configuration must be an object/mapping")
            print(f"  OK {path}")
            if "mcpServers" in data:
                print("    MCP server names: " + ", ".join(sorted(data["mcpServers"])))
        except (OSError, ValueError, yaml.YAMLError) as exc:
            print(f"  ERROR {path}: {exc}")
            failures += 1
    print("\nSkill source checkouts (no fetch or git writes)")
    for name, relative, upstream, _ in SOURCES:
        path = home / relative
        if path.exists():
            kind = "git checkout" if (path / ".git").exists() else "legacy file copy; use --offline or back up before recloning"
            print(f"  {name}: {path} ({kind}) https://github.com/{upstream}")
    cache = home / ".claude/skills-cache"
    manifest = load_json(cache / "sync-manifest.json", {})
    print("\nNative skill roots (filesystem/frontmatter audit, NOT a live harness loader test)")
    roots = harness_roots(home)
    for harness, paths in roots.items():
        for root in paths:
            if not root.exists():
                print(f"  {harness}: not configured ({root})")
                continue
            discovered = sorted(root.glob("*/SKILL.md"))
            print(f"  {harness}: {len(discovered)} one-level SKILL.md files at {root}")
            for skill in discovered:
                try:
                    sanitize_skill_md(skill)
                except (OSError, ValueError) as exc:
                    print(f"    ERROR {exc}")
                    failures += 1
    print("\nManaged content fingerprints")
    if manifest.get("version") != 2:
        print("  No v2 ownership manifest; run scripts/update-ecc.sh --offline to migrate safely")
    else:
        for root_value, records in manifest.get("destinations", {}).items():
            root = Path(root_value)
            for name, record in records.items():
                for relative, expected in record.get("files", {}).items():
                    path = root / safe_relative(name) / safe_relative(relative)
                    if actual_file(path) != expected:
                        print(f"  DRIFT {path}: locally edited or missing; updater will preserve edits and report conflicts")
                        failures += 1
        if not failures:
            print("  Recorded files match their installed fingerprints")
    print("\nShell integration")
    rc_files = [home / name for name in (".zshrc", ".bashrc", ".bash_profile", ".profile")]
    found = [str(path) for path in rc_files if path.is_file() and "Skills Layer" in path.read_text(errors="replace")]
    print("  " + (", ".join(found) if found else "No Skills Layer marker found; inspect safe-install.sh shell integration"))
    print("  LSP servers are optional; this audit does not configure or require one.")
    if args.probe_url:
        from urllib.parse import urlparse
        parsed = urlparse(args.probe_url)
        if parsed.scheme not in ("http", "https") or parsed.hostname not in ("localhost", "127.0.0.1", "::1"):
            parser.error("--probe-url must be an HTTP(S) loopback endpoint; remote network probes are not implicit")
        try:
            with urllib.request.urlopen(args.probe_url, timeout=5) as response:
                json.load(response)
            print(f"Model endpoint returned JSON: {args.probe_url}")
        except (OSError, ValueError, urllib.error.URLError) as exc:
            print(f"ERROR Model endpoint: {exc}")
            failures += 1
    print("\nFor upstream/content changes: scripts/update-ecc.sh --check (read-only network check)")
    print("For offline propagation preview: scripts/update-ecc.sh --offline --dry-run")
    print(f"Verification complete: {failures} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"ERROR {exc}", file=sys.stderr)
        sys.exit(1)
