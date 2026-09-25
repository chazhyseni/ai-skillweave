"""Fingerprint-owned delivery and explicit, reversible legacy conflict recovery."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import stat
import sys
import tempfile
from skill_sanitize import skill_name


def atomic_write(path: Path, data: bytes, mode: int = 0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".skillweave-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def fingerprint(data: bytes, mode: int):
    return {"sha256": hashlib.sha256(data).hexdigest(), "mode": mode}


def actual_file(path: Path):
    if path.is_symlink() or not path.is_file():
        return None
    return fingerprint(path.read_bytes(), stat.S_IMODE(path.stat().st_mode))


def safe_relative(value: str) -> Path:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or not path.parts:
        raise ValueError(f"Unsafe manifest path: {value!r}")
    return path


def safe_parents(path: Path, root: Path):
    current = path.parent
    while current != root:
        if current.is_symlink() or (current.exists() and not current.is_dir()):
            return False
        current = current.parent
    return True


def backup_conflict(target: Path, args):
    """Quarantine the whole entry, including personal additions, outside discovery.

    Never follow a symlink or remove the only copy. A same-filesystem rename makes
    recovery possible even if later delivery fails. Backups are never auto-pruned.
    """
    if args.preview:
        print(f"WOULD BACK UP {target} outside the skills root before replacement")
        return
    backup_root = target.parent.parent / "skillweave-backups"
    if backup_root.is_symlink():
        raise ValueError(f"Refusing symlinked backup directory: {backup_root}")
    backup_root.mkdir(parents=True, exist_ok=True)
    container = Path(tempfile.mkdtemp(prefix=target.name + "-", dir=backup_root))
    destination = container / target.name
    target.rename(destination)
    print(f"BACKUP {target} -> {destination} (includes personal additions; retained indefinitely)")


def matching_copy(target: Path, expected: dict):
    """Recognize unchanged old copies without requiring a legacy name manifest."""
    if not target.is_dir() or target.is_symlink():
        return None
    existing = {}
    for path in target.rglob("*"):
        if path.is_symlink():
            return None
        if path.is_file():
            relative = path.relative_to(target).as_posix()
            actual = actual_file(path)
            if relative not in expected or actual["sha256"] != expected[relative]["sha256"]:
                return None
            existing[relative] = actual
    # Old installers copied just SKILL.md; missing resources can now be filled in.
    return existing if "SKILL.md" in existing else None


def sync_root(root: Path, desired: dict, records: dict, protected: set, args) -> int:
    conflicts = 0
    aliases = {}
    for candidate in root.glob("*/SKILL.md"):
        if candidate.parent.name in desired:
            continue
        try:
            declared = skill_name(candidate)
        except (OSError, ValueError):
            continue
        if declared in desired and candidate.parent.name != declared:
            aliases.setdefault(declared, []).append(candidate.parent)
    alias_names = {path.name for paths in aliases.values() for path in paths}
    for name in sorted(set(desired) | set(records)):
        if len(safe_relative(name).parts) != 1:
            raise ValueError(f"Invalid skill directory in manifest: {name!r}")
        target = root / name
        old = records.get(name)
        wanted = desired.get(name)
        if name in alias_names:
            continue  # Handle legacy aliases with their canonical skill below.
        if old and old.get("source") in protected and (wanted is None or wanted[0] != old["source"]):
            print(f"PRESERVED {target}: source unavailable")
            continue
        if wanted is None and args.no_prune:
            continue
        files = wanted[2] if wanted else {}
        expected = {rel: fingerprint(*item) for rel, item in files.items()}
        replacing = False
        problems = []
        if target.is_symlink():
            if wanted and target.resolve() == wanted[1].resolve():
                replacing = True
                old = None
            else:
                problems.append("symlink differs from the selected source")
        elif old is None and target.exists():
            existing = matching_copy(target, expected)
            if wanted and existing:
                print(f"{'WOULD ADOPT' if args.preview else 'ADOPT'} unchanged legacy copy {target}")
                old = {"source": wanted[0], "files": existing}
            else:
                problems.append("unmanaged or differing legacy skill")
        old_files = dict(old.get("files", {})) if old else {}
        # Preflight the entire skill. Never install a new SKILL.md with stale scripts.
        if not problems and not replacing:
            for relative in sorted(set(files) | set(old_files)):
                destination = target / safe_relative(relative)
                if not safe_parents(destination, root):
                    problems.append(f"{relative}: parent is a symlink or non-directory")
                    continue
                present = destination.exists() or destination.is_symlink()
                actual = actual_file(destination) if present else None
                previous, upcoming = old_files.get(relative), expected.get(relative)
                if previous is not None and present and actual != previous and actual != upcoming:
                    problems.append(f"{relative}: locally edited")
                elif previous is None and present:
                    problems.append(f"{relative}: unowned file")
        current_aliases = [path for path in aliases.get(name, []) if path.exists() or path.is_symlink()]
        if current_aliases and not getattr(args, "repair_conflicts", False):
            problems.append("duplicate declared name in " + ", ".join(str(path) for path in current_aliases))
        elif current_aliases:
            for alias in current_aliases:
                backup_conflict(alias, args)
                records.pop(alias.name, None)
        if problems:
            if wanted and getattr(args, "repair_conflicts", False):
                backup_conflict(target, args)
                replacing = True
                old_files = {}
            else:
                print(f"CONFLICT {target}: {'; '.join(problems)}; entire skill preserved. "
                      "Review --repair-conflicts --dry-run for backup-and-replace recovery.", file=sys.stderr)
                conflicts += 1
                continue
        elif replacing and not args.preview:
            target.unlink()  # Source-directory symlink only; its target is untouched.
        retained = dict(old_files)
        for relative in sorted(set(files) | set(old_files)):
            destination = target / safe_relative(relative)
            present = not replacing and (destination.exists() or destination.is_symlink())
            actual = actual_file(destination) if present else None
            upcoming = expected.get(relative)
            if upcoming is not None:
                if actual != upcoming:
                    print(f"{'WOULD WRITE' if args.preview else 'WRITE'} {destination}")
                    if not args.preview:
                        atomic_write(destination, *files[relative])
                retained[relative] = upcoming
            elif not args.no_prune:
                if present:
                    print(f"{'WOULD PRUNE' if args.preview else 'PRUNE'} {destination}")
                    if not args.preview:
                        destination.unlink()
                retained.pop(relative, None)
        if retained:
            records[name] = {"source": wanted[0] if wanted else old["source"], "files": retained}
        else:
            records.pop(name, None)
        if not args.preview and target.is_dir() and not target.is_symlink():
            for directory, _, _ in os.walk(target, topdown=False):
                try:
                    Path(directory).rmdir()
                except OSError:
                    pass
    return conflicts
