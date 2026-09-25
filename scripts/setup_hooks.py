"""Install Claude hooks, upgrading owned files while preserving custom hooks."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HOME = Path.home()
DEST = HOME / ".claude/hooks"
LEGACY = {
    "codesight-redirect.sh": "ac4a6287a3828ac592dac2e04a1a18878bea3e7ab079f73dfeab843662239e60",
    "learning-capture.sh": "ff48e2f869f83bf4997d2afc0cc5ceb9b150c58ad8020a8cfcf62a2dbbb22848",
}
HOOKS = {
    "codesight-redirect.sh": ("PreToolUse", "Glob|Grep"),
    "codesight-summary.sh": ("PostToolUse", "mcp__codesight__codesight_get_summary"),
    "session-cleanup.sh": ("SessionEnd", None),
    "learning-capture.sh": ("UserPromptSubmit", None),
}


def load_object(path):
    value = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def atomic_write(path, data, mode=0o600):
    fd, temporary = tempfile.mkstemp(prefix=".skillweave-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def matches(command, name):
    if not isinstance(command, str):
        return False
    try:
        words = shlex.split(command)
    except ValueError:
        return False
    paths = {str(DEST / name), str(ROOT / "hooks" / name),
             str(HOME / ".claude/scripts/hooks" / name)}
    return (len(words) == 1 and words[0] in paths or
            len(words) == 2 and words[0] in ("bash", "/bin/bash") and words[1] in paths)


def install(learning):
    settings_path = HOME / ".claude/settings.json"
    manifest_path = DEST / ".skillweave-manifest.json"
    # Validate all state before copying or changing registrations.
    for path in (settings_path, manifest_path, DEST, DEST.parent):
        if path.is_symlink():
            raise ValueError(f"Refusing symlinked hook configuration: {path}")
    settings = load_object(settings_path)
    owned = load_object(manifest_path)
    hooks = settings.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise ValueError("settings.hooks must be an object")
    for event, groups in hooks.items():
        if not isinstance(groups, list):
            raise ValueError(f"hooks.{event} must be an array")
        for group in groups:
            if not isinstance(group, dict) or not isinstance(group.get("hooks"), list):
                raise ValueError(f"Invalid hook group in {event}")
            if any(not isinstance(item, dict) for item in group["hooks"]):
                raise ValueError(f"Invalid hook entry in {event}")
            learning = learning or any(matches(item.get("command"), "learning-capture.sh")
                                       for item in group["hooks"])
    selected = [name for name in HOOKS if learning or name != "learning-capture.sh"]
    files = ["skillweave_hooks.py", *selected]
    contents = {}
    conflicts = []
    for name in files:
        target = DEST / name
        source = (ROOT / "hooks" / name).read_bytes()
        if target.is_symlink():
            conflicts.append(str(target))
        elif target.exists() and digest(target.read_bytes()) not in (
                digest(source), owned.get(name), LEGACY.get(name)):
            conflicts.append(str(target))
        contents[name] = source
    if conflicts:
        print("Hooks unchanged; custom files preserved: " + ", ".join(conflicts), file=sys.stderr)
        return
    DEST.mkdir(parents=True, exist_ok=True)
    for name, content in contents.items():
        target = DEST / name
        if not target.exists() or target.read_bytes() != content:
            atomic_write(target, content, 0o755 if name.endswith(".sh") else 0o600)
        owned[name] = digest(content)
    # Remove only recognized registrations, retaining other hooks in shared groups.
    for event, groups in list(hooks.items()):
        retained = []
        for group in groups:
            items = [item for item in group["hooks"]
                     if not any(matches(item.get("command"), name)
                                for name in (*selected, "session-reflection.sh"))]
            if items or not group["hooks"]:
                retained.append({**group, "hooks": items})
        if retained:
            hooks[event] = retained
        else:
            del hooks[event]
    for name in selected:
        event, matcher = HOOKS[name]
        group = {"hooks": [{"type": "command", "command": shlex.quote(str(DEST / name)), "timeout": 5}]}
        if matcher:
            group["matcher"] = matcher
        hooks.setdefault(event, []).append(group)
    data = (json.dumps(settings, indent=2) + "\n").encode()
    if not settings_path.exists() or settings_path.read_bytes() != data:
        atomic_write(settings_path, data)
    atomic_write(manifest_path, (json.dumps(owned, indent=2) + "\n").encode())
    print("Claude hooks installed; correction capture " + ("enabled." if learning else "not enabled."))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--learning", action="store_true", help="Opt in to local correction capture")
    args = parser.parse_args()
    try:
        install(args.learning)
    except (OSError, ValueError) as exc:
        print(f"Hook setup: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
