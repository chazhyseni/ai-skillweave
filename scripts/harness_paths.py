"""Native OMP paths shared by delivery, extraction and model setup.

Upstream contract: oh-my-pi packages/utils/src/dirs.ts. Skills/models use the
agent config directory; sessions may use an already-migrated XDG data directory.
"""
import os
from pathlib import Path
import re
import sys


def omp_profile():
    value = os.environ.get("OMP_PROFILE", os.environ.get("PI_PROFILE", "")).strip()
    if not value or value == "default":
        return None
    if (not re.fullmatch(r"[a-z0-9][a-z0-9._-]{0,63}", value) or value.endswith(".")
            or re.match(r"^(con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)", value)):
        raise ValueError(f"Invalid OMP profile: {value!r}")
    return value


def omp_config_root(home: Path):
    return home / os.environ.get("PI_CONFIG_DIR", ".omp")


def omp_agent_dirs(home: Path, all_profiles=True):
    override = os.environ.get("SKILLWEAVE_OMP_AGENT_DIR")
    if override:
        return [Path(override).expanduser().absolute()]
    root = omp_config_root(home)
    profile = omp_profile()
    if profile:
        return [root / "profiles" / profile / "agent"]
    override = os.environ.get("PI_CODING_AGENT_DIR")
    if override:
        return [Path(override).expanduser().absolute()]
    paths = [root / "agent"]
    if all_profiles:
        paths.extend(sorted((root / "profiles").glob("*/agent")))
    return paths


def omp_session_dirs(home: Path):
    result = []
    root = omp_config_root(home)
    for agent in omp_agent_dirs(home):
        sessions = agent / "sessions"
        xdg = os.environ.get("XDG_DATA_HOME")
        if xdg and sys.platform in ("linux", "darwin"):
            if agent == root / "agent":
                candidate = Path(xdg) / "omp"
            elif agent.parent.parent == root / "profiles":
                candidate = Path(xdg) / "omp/profiles" / agent.parent.name
            else:
                candidate = None
            if candidate and candidate.is_dir():
                sessions = candidate / "sessions"
        result.append(sessions)
    return result
