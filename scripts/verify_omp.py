#!/usr/bin/env python3
"""Verify every delivered skill through OMP's real loader, without inference.

Run from the project where OMP will be used so project-level shadowing is visible.
OMP may initialize its own settings/cache. No model requests or skill scripts run.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import quote

import yaml

from harness_paths import omp_agent_dirs
from skill_sanitize import skill_name


def verify(root: Path, executable: str, timeout: float):
    env = dict(os.environ, PI_CODING_AGENT_DIR=str(root.parent))
    # Each root is checked in isolation, including existing named profiles.
    env.pop("OMP_PROFILE", None)
    env.pop("PI_PROFILE", None)
    names = set()
    checked = skipped = failures = 0
    for path in sorted(root.glob("*/SKILL.md")):
        try:
            name = skill_name(path)
            content = path.read_text(encoding="utf-8")
            metadata = yaml.safe_load(content.split("---", 2)[1])
            if metadata.get("enabled") is False:
                print(f"DISABLED {path}")
                skipped += 1
                continue
            if name in names:
                raise ValueError(f"duplicate declared name {name!r}; migrate legacy aliases before verifying")
            names.add(name)
            result = subprocess.run([executable, "read", f"skill://{quote(name, safe='-')}:raw"],
                                    env=env, capture_output=True, text=True, timeout=timeout)
            if result.returncode:
                raise ValueError(f"not discoverable: {(result.stderr or result.stdout).strip()[:300]}")
            if result.stdout.rstrip("\n") != content.rstrip("\n"):
                raise ValueError("native read differs from installed content (shadowing or unsupported read CLI); inspect omp read skill://" + name)
            checked += 1
        except (OSError, ValueError, yaml.YAMLError, subprocess.TimeoutExpired) as exc:
            print(f"ERROR {path}: {exc}", file=sys.stderr)
            failures += 1
    if not checked and not skipped:
        print(f"ERROR no discoverable skills at {root}", file=sys.stderr)
        failures += 1
    print(f"OMP native loader: {checked} content-verified, {skipped} intentionally disabled, {failures} failed at {root}")
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=float, default=30, help="seconds allowed per native read")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    executable = shutil.which("omp")
    if not executable:
        parser.error("omp is not on PATH; install the official binary before native verification")
    failures = sum(verify(agent / "skills", executable, args.timeout) for agent in omp_agent_dirs(Path.home()))
    return int(failures > 0)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError) as exc:
        print(f"OMP verification failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
