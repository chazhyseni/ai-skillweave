"""Local, stdlib-only Claude hooks. No inference, subprocesses, or network calls."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import sys
from datetime import datetime, timezone

HOME = Path.home().resolve()
STATE = HOME / ".claude/state/skillweave-hooks"
EVENTS = HOME / ".claude/skills/learned/events"


def digest(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def private_directory(path):
    current = HOME
    for part in path.relative_to(HOME).parts:
        current /= part
        if current.is_symlink():
            raise ValueError(f"Refusing symlinked hook state: {current}")
        current.mkdir(mode=0o700, exist_ok=True)
    return path


def session_directory(data):
    session = data.get("session_id")
    if not isinstance(session, str) or not session:
        raise ValueError("Hook payload requires a session_id")
    return STATE / digest(session)


def project_directory(data):
    cwd = data.get("cwd")
    if not isinstance(cwd, str) or not Path(cwd).is_absolute():
        raise ValueError("Hook payload requires an absolute cwd")
    inputs = data.get("tool_input", {})
    path = inputs.get("path") or inputs.get("file_path") or cwd
    if not isinstance(path, str):
        raise ValueError("Tool path must be a string")
    start = (Path(cwd) / path).resolve()
    if start.is_file():
        start = start.parent
    for candidate in (start, *start.parents):
        if (candidate / ".codesight").is_dir():
            return candidate
    return None


def codesight_configured(project):
    config = HOME / ".claude.json"
    settings = json.loads(config.read_text()) if config.is_file() else {}
    servers = settings.get("mcpServers", {})
    project_servers = settings.get("projects", {}).get(str(project), {}).get("mcpServers", {})
    if "codesight" in servers or "codesight" in project_servers:
        return True
    for parent in (project, *project.parents):
        config = parent / ".mcp.json"
        if config.is_file() and "codesight" in json.loads(config.read_text()).get("mcpServers", {}):
            return True
    return False


def mark_seen(data, project):
    directory = private_directory(session_directory(data))
    marker = directory / (digest(str(project)) + ".seen")
    try:
        fd = os.open(marker, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
    except FileExistsError:
        return False
    os.close(fd)
    return True


def codesight(data):
    tool = data.get("tool_name")
    if tool not in ("Glob", "Grep"):
        return 0
    inputs = data.get("tool_input", {})
    pattern = inputs.get("pattern", "")
    if not isinstance(pattern, str):
        return 0
    if "**" not in pattern and not (tool == "Glob" and not inputs.get("path")):
        return 0
    project = project_directory(data)
    if project is None or not codesight_configured(project):
        return 0
    if mark_seen(data, project):
        print("This project has a Codesight index. Call "
              "mcp__codesight__codesight_get_summary before broad Glob/Grep searches. "
              "If Codesight is unavailable, retry the search; this reminder runs once "
              "per project and session.", file=sys.stderr)
        return 2
    return 0


def summary_used(data):
    if data.get("tool_name") != "mcp__codesight__codesight_get_summary":
        return 0
    response = data.get("tool_response", {})
    if isinstance(response, dict) and response.get("isError"):
        return 0
    project = project_directory(data)
    if project is not None:
        mark_seen(data, project)
    return 0


def capture(data):
    prompt = data.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        return 0
    patterns = (
        ("correction", r"\b(?:instead of|don't|do not|never|actually|wrong|incorrect|stop doing)\b"),
        ("preference", r"\b(?:always|prefer|remember to|make sure|from now on)\b"),
        ("pattern", r"\b(?:when|whenever|if)\b.+\b(?:use|avoid|should|must)\b"),
    )
    kind = next((kind for kind, pattern in patterns if re.search(pattern, prompt, re.I | re.S)), None)
    if kind is None:
        return 0
    session = session_directory(data).name
    cwd = data.get("cwd")
    if not isinstance(cwd, str) or not Path(cwd).is_absolute():
        raise ValueError("Hook payload requires an absolute cwd")
    directory = private_directory(EVENTS / digest(cwd))
    record = {"type": "user", "sessionId": data["session_id"], "cwd": cwd,
              "timestamp": datetime.now(timezone.utc).isoformat(),
              "message": {"role": "user", "content": prompt},
              "skillweave_capture": kind}
    fd = os.open(directory / (session + ".jsonl"),
                 os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "a", encoding="utf-8") as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        stream.write(json.dumps(record, ensure_ascii=False) + "\n")
    return 0


def cleanup(data):
    directory = session_directory(data)
    if not directory.exists():
        return 0
    private_directory(directory)
    for marker in directory.glob("*.seen"):
        marker.unlink()
    directory.rmdir()
    return 0


def main():
    handlers = {"codesight": ("PreToolUse", codesight),
                "summary": ("PostToolUse", summary_used),
                "capture": ("UserPromptSubmit", capture),
                "cleanup": ("SessionEnd", cleanup)}
    try:
        event, handler = handlers[sys.argv[1]]
        data = json.load(sys.stdin)
        if not isinstance(data, dict):
            raise ValueError("Hook payload must be an object")
        if data.get("hook_event_name") != event:
            return 0
        return handler(data)
    except (OSError, ValueError, TypeError, KeyError, IndexError) as exc:
        print(f"Skillweave hook: {exc}", file=sys.stderr)
        return 1  # Claude treats non-policy hook failures as non-blocking.


if __name__ == "__main__":
    sys.exit(main())
