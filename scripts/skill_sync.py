#!/usr/bin/env python3
"""Source updates and ownership-aware native skill delivery for every harness."""
from __future__ import annotations

import argparse
import json
import re
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

from skill_sanitize import sanitize_skill_md, skill_name
from skill_delivery import atomic_write, backup_conflict, sync_root
from harness_paths import omp_agent_dirs

# Low to high priority, matching the historical cross-harness source ordering.
# id, checkout relative to HOME, upstream, skill roots (first existing wins).
SOURCES = (
    ("codex-curated", ".claude-curated-skills/openai-codex", "openai/skills", ("skills",)),
    ("bioskills", ".claude/skills-cache/bioskills-src", "GPTomics/bioSkills", (".",)),
    ("sciagent", ".claude-sciagent-skills", "jaechang-hits/SciAgent-Skills", ("skills",)),
    ("operon", ".claude-operon-skills", "swaruplab/operon", ("protocols",)),
    ("medical", ".claude-medical-skills", "FreedomIntelligence/OpenClaw-Medical-Skills", ("skills",)),
    ("tooluniverse", ".claude-tooluniverse", "mims-harvard/ToolUniverse", ("skills",)),
    ("life-sciences", ".claude-life-sciences", "anthropics/life-sciences", (".",)),
    ("bionemo", ".claude-bionemo-skills", "NVIDIA-BioNeMo/bionemo-agent-toolkit", ("skills/bionemo-agent-toolkit/skills", ".")),
    ("nature-paper", ".claude-nature-paper-skills", "Boom5426/Nature-Paper-Skills", ("skills",)),
    ("deepmind", ".claude-deepmind-skills", "google-deepmind/science-skills", ("skills",)),
    ("aws-hcls", ".claude-aws-hcls-skills", "awslabs/hcls-agent-skills", ("skills",)),
    ("openai-life-sciences", ".claude-openai-life-sciences", "openai/plugins", ("plugins/life-science-research/skills",)),
    ("stjude-cab", ".claude-stjude-cab-skills", "stjudecab/CAB-aiSkills", (".",)),
    ("huggingface", ".claude-huggingface-skills", "huggingface/skills", ("skills",)),
    ("anthropic", ".claude-curated-skills/anthropic-official", "anthropics/skills", ("skills",)),
    ("bio", ".claude-clawbio-skills", "ClawBio/ClawBio", ("skills",)),
    ("science", ".claude-scientific-skills", "K-Dense-AI/scientific-agent-skills", ("skills", "scientific-skills")),
    ("bipartite", ".claude-bipartite", "matsen/bipartite", ("skills",)),
    ("ecc", ".claude-everything-claude-code", "affaan-m/ECC", ("skills",)),
)
HF_SKILLS = {"hf-cli", "hf-mem", "huggingface-local-models", "huggingface-community-evals", "huggingface-datasets"}
GROUPS = {"curated": ("anthropic", "codex-curated")}
GROUPS.update({name: (name,) for name in ("ecc", "science", "bio", "bioskills", "huggingface")})


def load_json(path: Path, default):
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as exc:
        raise ValueError(f"Cannot read {path}; repair it before syncing: {exc}") from exc



def save_json(path: Path, value):
    atomic_write(path, (json.dumps(value, indent=2, sort_keys=True) + "\n").encode())


def git(path: Path, *args: str) -> str:
    result = subprocess.run(["git", "--no-optional-locks", "-C", str(path), *args],
                            capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f"git {' '.join(args)} in {path}: {result.stderr.strip()}")
    return result.stdout.strip()


def clone_source(path: Path, upstream: str, replace: bool = False):
    """Clone before moving existing data; retain the complete old source outside discovery."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".skillweave-clone-", dir=path.parent) as tmp:
        candidate = Path(tmp) / "repo"
        result = subprocess.run(["git", "clone", "--depth", "1", "--quiet",
                                 f"https://github.com/{upstream}.git", str(candidate)])
        if result.returncode:
            raise RuntimeError(f"Clone failed for {upstream}; existing source unchanged")
        git(candidate, "rev-parse", "--verify", "HEAD")
        backup = None
        if replace:
            backup_root = path.parent / "skillweave-source-backups"
            if backup_root.is_symlink():
                raise RuntimeError(f"Refusing symlinked source backup root: {backup_root}")
            backup_root.mkdir(exist_ok=True)
            backup = Path(tempfile.mkdtemp(prefix=path.name + "-", dir=backup_root)) / path.name
            path.rename(backup)
            print(f"SOURCE BACKUP {path} -> {backup}", flush=True)
        try:
            candidate.rename(path)
        except OSError:
            if backup is not None:
                # If restoration itself fails, the printed backup remains intact.
                backup.rename(path)
            raise
    print(f"{'REPLACED' if replace else 'CLONED'} {upstream}")


def update_source(path: Path, upstream: str, preview: bool, offline: bool,
                  repair: bool = False, use_local: bool = False):
    if offline:
        return
    if path.is_symlink():
        raise RuntimeError(f"{path}: source symlink preserved; use --offline or manage its target explicitly")
    if not path.exists():
        if preview:
            print(f"MISSING {path}: would clone https://github.com/{upstream}.git")
            return
        clone_source(path, upstream)
        return
    reason = None
    if not (path / ".git").exists():
        reason = "legacy file-copy source has no git history"
    elif git(path, "status", "--porcelain"):
        reason = "source contains local changes"
    if reason:
        if use_local and not repair:
            print(f"LOCAL {path.name}: using existing skills ({reason}); "
                  "upstream refresh skipped, use --repair-sources for backup-first replacement")
            return
        if not repair:
            raise RuntimeError(f"{path}: {reason}; preserved. Use --offline to sync the working copy, "
                               "or --repair-sources to back it up and clone canonical upstream.")
        if preview:
            print(f"WOULD REPLACE {path}: {reason}; clone {upstream} first, then back up the entire source")
            return
        clone_source(path, upstream, replace=True)
        return
    branch = git(path, "symbolic-ref", "--quiet", "--short", "HEAD")
    remote = git(path, "config", f"branch.{branch}.remote")
    ref = git(path, "config", f"branch.{branch}.merge")
    if preview:
        # ls-remote does not change refs, FETCH_HEAD, index, or the working tree.
        result = git(path, "ls-remote", "--exit-code", remote, ref)
        remote_head = result.split()[0]
        current = git(path, "rev-parse", "HEAD")
        print(f"{'CURRENT' if current == remote_head else 'UPDATE AVAILABLE'} {path.name}: {current[:12]} -> {remote_head[:12]}")
    else:
        before = git(path, "rev-parse", "HEAD")
        git(path, "fetch", "--quiet", remote, ref)
        git(path, "merge", "--ff-only", "--quiet", "FETCH_HEAD")
        after = git(path, "rev-parse", "HEAD")
        print(f"{'CURRENT' if before == after else 'UPDATED'} {path.name}: {after[:12]}")


def skill_dirs(root: Path):
    if not root.is_dir():
        return
    for directory, dirs, files in os.walk(root):
        # Codex curated skills intentionally live under .curated/.experimental.
        dirs[:] = sorted(d for d in dirs if (not d.startswith(".") or d in (".curated", ".experimental"))
                         and d not in ("legacy", "node_modules", "__pycache__"))
        if "SKILL.md" in files:
            yield Path(directory)
            dirs[:] = []




def payload(path: Path):
    """Copy the entire skill, including executable scripts and referenced assets."""
    if path.is_file():
        return {"SKILL.md": (sanitize_skill_md(path).encode(), 0o644)}
    result = {}
    boundary = path.resolve()

    def visit(directory: Path, ancestors: set):
        resolved = directory.resolve()
        if resolved in ancestors:
            raise ValueError(f"{directory}: cyclic source asset symlink")
        ancestors = ancestors | {resolved}
        for item in sorted(directory.iterdir()):
            if item.name in (".git", "__pycache__"):
                continue
            target = item.resolve()
            if target != boundary and boundary not in target.parents:
                raise ValueError(f"{item}: asset escapes the skill directory; vendor it inside the skill before syncing")
            if item.is_dir():
                visit(item, ancestors)
            elif item.is_file():
                relative = item.relative_to(path).as_posix()
                data = sanitize_skill_md(item).encode() if relative == "SKILL.md" else item.read_bytes()
                result[relative] = (data, stat.S_IMODE(item.stat().st_mode))
            else:
                raise ValueError(f"{item}: unsupported or dangling source asset")

    visit(path, set())
    return result


def curated_payload(source: str, checkout: Path, skill: Path):
    """Apply explicit portability decisions without changing upstream checkouts."""
    if source == "stjude-cab" and skill.name == "genomic-regions-annotation":
        print("CURATED OUT stjude-cab/genomic-regions-annotation: institution-specific external annotation symlinks")
        return None
    files = payload(skill)
    if source == "stjude-cab" and skill.name == "custom-ES-plot-GSEApy":
        name = "custom-es-plot-gseapy"
        text, mode = files["SKILL.md"]
        text, changed = re.subn(rb"(?m)^name: custom-ES-plot-GSEApy\r?$",
                               b"name: custom-es-plot-gseapy", text, count=1)
        if not changed:
            name = skill_name(skill / "SKILL.md")
        files["SKILL.md"] = (text, mode)
    else:
        name = skill_name(skill / "SKILL.md")
    if source in ("aws-hcls", "openai-life-sciences", "stjude-cab"):
        for original, destination in (("LICENSE", "UPSTREAM-LICENSE"), ("LICENSE.txt", "UPSTREAM-LICENSE.txt"),
                                      ("AUTHORS.md", "UPSTREAM-AUTHORS.md")):
            if (checkout / original).is_file():
                files[destination] = ((checkout / original).read_bytes(), 0o644)
    return name, files






def harness_roots(home: Path):
    return {
        "claude": [home / ".claude/skills"],
        "codex": [home / ".agents/skills"],
        "openclaw": [home / ".openclaw/workspace/skills"],
        "pi": [Path(os.environ.get("PI_CODING_AGENT_DIR", home / ".pi/agent")).expanduser() / "skills"],
        "copilot": [home / ".copilot/skills"],
        "hermes": [home / ".hermes/skills/ai-skillweave"],
        "omp": [directory / "skills" for directory in omp_agent_dirs(home)],
    }




def rebuild_cache(cache: Path, desired: dict, preview: bool):
    if preview:
        return
    combined = []
    learned = []
    for name, (source, _, files) in sorted(desired.items()):
        text = files["SKILL.md"][0].decode()
        combined.append(f"\n# {name} ({source})\n\n{text}")
        if source == "learned":
            import re
            desc = re.search(r"^description:\s*(.+)$", text, re.M)
            learned.append(f"- **{name}**: {desc.group(1) if desc else name}")
    atomic_write(cache / "combined-skills.txt", ("# Skill library (reference only)\n" + "\n".join(combined)).encode())
    atomic_write(cache / "lean-skills.txt", ("# Learned skills (up to 50)\n" + "\n".join(learned[:50]) + "\n").encode())


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--check", action="store_true", help="read-only remote revision check and sync preview; never fetch")
    result.add_argument("--dry-run", action="store_true", help="preview only; never write or fetch")
    result.add_argument("--offline", "--no-fetch", action="store_true", help="sync existing source trees without network")
    result.add_argument("--no-prune", action="store_true")
    result.add_argument("--uninstall", action="store_true", help="remove unchanged manifest-owned files only")
    result.add_argument("--repair-conflicts", action="store_true",
                        help="back up conflicting skill directories, then replace with selected sources; personal additions remain in backups")
    result.add_argument("--repair-sources", action="store_true",
                        help="clone canonical upstream before backing up and replacing legacy/dirty source trees")
    result.add_argument("--harness", action="append", choices=("claude", "codex", "openclaw", "pi", "copilot", "hermes", "omp"))
    for group in GROUPS:
        selection = result.add_mutually_exclusive_group()
        selection.add_argument(f"--with-{group}", dest=group, action="store_true", default=None)
        selection.add_argument(f"--without-{group}", dest=group, action="store_false")
    result.add_argument("--with-source", action="append", choices=[s[0] for s in SOURCES], default=[])
    result.add_argument("--without-source", action="append", choices=[s[0] for s in SOURCES], default=[])
    result.add_argument("--bioskills-categories", help="comma-separated category selection, persisted; empty means all")
    result.add_argument("--list-sources", action="store_true")
    # These options remain accepted by installer callers; extraction is separate.
    for option in ("--force", "--install", "--no-learn", "--no-llm"):
        result.add_argument(option, action="store_true", help=argparse.SUPPRESS)
    return result


def main(argv=None):
    args = parser().parse_args(argv)
    if args.repair_sources and (args.offline or args.uninstall):
        parser().error("--repair-sources requires online source updates, not --offline or --uninstall")
    args.preview = args.check or args.dry_run
    home = Path.home()
    cache = home / ".claude/skills-cache"
    preferences = load_json(cache / "source-preferences.json", {})
    enabled = preferences.setdefault("enabled", {})
    for group, ids in GROUPS.items():
        if getattr(args, group) is not None:
            for source in ids:
                enabled[source] = getattr(args, group)
    enabled.update({source: True for source in args.with_source})
    enabled.update({source: False for source in args.without_source})
    if args.bioskills_categories is not None:
        preferences["bioskills_categories"] = [part.strip() for part in args.bioskills_categories.split(",") if part.strip()]
    active = {source: enabled.get(source, source == "ecc" or (home / relative).exists())
              for source, relative, _, _ in SOURCES}
    if args.list_sources:
        for source, relative, upstream, _ in SOURCES:
            print(f"{source}\t{'enabled' if active[source] else 'disabled'}\t{home / relative}\thttps://github.com/{upstream}")
        return 0
    manifest = load_json(cache / "sync-manifest.json", {})
    if manifest.get("version") not in (None, 2):
        raise ValueError("Unknown sync manifest version; refusing to alter managed files")
    destinations = manifest.setdefault("destinations", {})
    desired = {}
    protected = set()
    errors = 0
    if not args.uninstall:
        for source, relative, upstream, roots in SOURCES:
            if not active[source]:
                continue
            if source == "bioskills":
                print("WARNING bioSkills was archived upstream in August 2026; no upstream fixes are expected")
            checkout = home / relative
            try:
                update_source(checkout, upstream, args.preview, args.offline, args.repair_sources, args.install)
            except (OSError, RuntimeError) as exc:
                print(f"ERROR {exc}", file=sys.stderr)
                protected.add(source)
                errors += 1
                continue
            root = next((checkout / part for part in roots if (checkout / part).is_dir()), None)
            if root is None:
                protected.add(source)
                print(f"UNAVAILABLE {source}: no local skills root (existing managed files preserved)")
                if not args.preview:
                    errors += 1
                continue
            for skill in skill_dirs(root):
                if source == "huggingface" and skill.name not in HF_SKILLS:
                    continue
                categories = preferences.get("bioskills_categories", [])
                if source == "bioskills" and categories and skill.relative_to(root).parts[0] not in categories:
                    continue
                try:
                    curated = curated_payload(source, checkout, skill)
                    if curated is None:
                        continue
                    name, content = curated
                    if name in desired:
                        print(f"PRIORITY {name}: {source} overrides {desired[name][0]}")
                    desired[name] = (source, skill, content)
                except (OSError, ValueError) as exc:
                    protected.add(source)
                    print(f"ERROR {exc}", file=sys.stderr)
                    errors += 1
        learned_dir = home / ".claude/skills/learned"
        for skill in sorted(learned_dir.glob("*.md")):
            if skill.name.startswith(".") or skill.name == "SKILL.md":
                continue
            try:
                desired[skill_name(skill)] = ("learned", skill, payload(skill))
            except (OSError, ValueError) as exc:
                protected.add("learned")
                print(f"ERROR {exc}", file=sys.stderr)
                errors += 1
    roots = harness_roots(home)
    args.input_roots = {home / ".claude/skills/learned"}
    # Retire only fingerprint-owned legacy Codex copies; old name-only manifests
    # cannot prove ownership or local edits and are deliberately not pruned.
    legacy_codex = home / ".codex/skills"
    seen = set()
    for harness, paths in roots.items():
        if args.harness and harness not in args.harness:
            continue
        for root in paths:
            base = home / f".{harness}"
            if not args.harness and not root.parent.exists() and not base.exists() and harness != "claude":
                continue
            # Old Copilot installs alias Claude's entire skills root. Leave the
            # alias intact; the same files must not get a second ownership record.
            if root.is_symlink():
                if harness == "copilot" and root.resolve() == (home / ".claude/skills").resolve():
                    if args.uninstall:
                        print(f"{'WOULD UNLINK' if args.preview else 'UNLINK'} legacy Copilot alias {root}")
                        if not args.preview:
                            root.unlink()
                        continue
                    root = home / ".claude/skills"
                else:
                    print(f"CONFLICT {root}: custom skills-root symlink preserved", file=sys.stderr)
                    errors += 1
                    continue
            if any(parent.is_symlink() for parent in root.parents if home in parent.parents):
                print(f"CONFLICT {root}: parent symlink preserved; use a real native skills directory", file=sys.stderr)
                errors += 1
                continue
            if str(root) in seen:
                continue
            seen.add(str(root))
            if not args.preview:
                root.mkdir(parents=True, exist_ok=True)
            records = destinations.setdefault(str(root), {})
            args.backup_root = (home / ".hermes" if harness == "hermes" else root.parent) / "skillweave-backups"
            if harness == "hermes":
                legacy_backups = root.parent / "skillweave-backups"
                if legacy_backups.exists() or legacy_backups.is_symlink():
                    backup_conflict(legacy_backups, args)
            root_errors = sync_root(root, desired, records, protected, args)
            errors += root_errors
            print(f"{harness}: {len(records)} ownership records, {root_errors} conflicting skill(s) at {root}")
    if (not errors and str(legacy_codex) in destinations
            and (not args.harness or "codex" in args.harness)
            and not legacy_codex.is_symlink()):
        errors += sync_root(legacy_codex, {}, destinations[str(legacy_codex)], protected, args)
    if not args.preview:
        save_json(cache / "sync-manifest.json", {"version": 2, "destinations": destinations})
        if not args.uninstall:
            enabled.update(active)
            save_json(cache / "source-preferences.json", preferences)
            rebuild_cache(cache, desired, False)
    print(f"{'Preview' if args.preview else 'Sync'}: {len(desired)} skills, {errors} error(s)/conflict(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError) as error:
        print(f"ERROR {error}", file=sys.stderr)
        sys.exit(1)
