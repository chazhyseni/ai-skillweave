#!/usr/bin/env python3
"""Opt-in model setup. Preserve unrelated harness settings; never install packages."""

import argparse
import copy
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
from datetime import datetime

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from model_backend import add_backend_arguments, backend_from_args


def load_config(path):
    if not path.exists():
        return {}
    text = path.read_text()
    try:
        value = json.loads(text)
    except ValueError:
        try:
            if path.suffix in (".yml", ".yaml"):
                import yaml
                value = yaml.safe_load(text)
            else:
                import json5
                value = json5.loads(text)
        except ImportError as exc:
            package = "PyYAML" if path.suffix in (".yml", ".yaml") else "json5"
            raise ValueError(f"Preserving {path} requires {package}; install it in your chosen Python environment and re-run with SKILLWEAVE_PYTHON set to that interpreter") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a configuration object; left untouched")
    return value


def merge(current, additions):
    for key, value in additions.items():
        if isinstance(value, dict) and isinstance(current.get(key), dict):
            merge(current[key], value)
        elif key == "models" and isinstance(value, list) and isinstance(current.get(key), list) and all(isinstance(item, dict) and "id" in item for item in value + current[key]):
            by_id = {item["id"]: item for item in current[key]}
            for item in value:
                if item["id"] in by_id:
                    merge(by_id[item["id"]], item)
                else:
                    current[key].append(copy.deepcopy(item))
        else:
            current[key] = copy.deepcopy(value)
    return current


def save_config(path, content):
    if path.is_symlink():
        raise ValueError(f"Refusing to replace symlink {path}; configure its target explicitly")
    if path.exists() and path.read_text() == content:
        print(f"Unchanged: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        backup = path.with_name(path.name + ".bak_skillweave_" + datetime.now().strftime("%Y%m%d_%H%M%S_%f"))
        shutil.copy2(path, backup)
        print(f"Backup: {backup}")
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".skillweave-")
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(content)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)
    print(f"Configured: {path}")


def rendered_template(name, values):
    template = json.loads((ROOT / "configs" / name).read_text())

    def render(value):
        if isinstance(value, str):
            for key, replacement in values.items():
                value = value.replace("{{" + key + "}}", replacement)
            return value
        if isinstance(value, dict):
            return {key: render(item) for key, item in value.items() if not key.startswith("_")}
        if isinstance(value, list):
            return [render(item) for item in value]
        return value

    return render(template)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("harness", choices=("codex", "pi", "openclaw", "omp", "ollama"))
    add_backend_arguments(parser)
    parser.add_argument("--validate-only", action="store_true", help="Validate backend options without reading or writing harness configuration")
    args = parser.parse_args()
    if not any(getattr(args, "backend_" + key) is not None for key in ("backend", "model", "base_url", "context", "max_tokens", "timeout", "allow_remote")) and not any(key.startswith("SKILLWEAVE_LLM_") for key in os.environ):
        print("Existing model choices preserved. To opt in, pass --backend ollama or --backend llama.cpp --model SERVER_ALIAS.")
        return 0
    backend = backend_from_args(args)
    if args.validate_only:
        print(f"Valid backend: {backend.backend}/{backend.model} at {backend.base_url}")
        return 0
    home = Path.home()
    provider_id = "skillweave-local"
    model = {
        "id": backend.model, "name": backend.model, "reasoning": False, "input": ["text"],
        "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
        "contextWindow": backend.context, "maxTokens": backend.max_tokens,
    }
    provider = {"baseUrl": backend.openai_url, "api": "openai-completions", "models": [model]}
    values = {"MODEL": backend.model, "PROVIDER": provider_id}
    pending = []
    if args.harness == "codex":
        target = Path(os.environ.get("CODEX_HOME", home / ".codex")) / "skillweave-local.config.toml"
        text = (ROOT / "configs" / "codex-config.toml").read_text()
        for name, value in (("MODEL", backend.model), ("BASE_URL", backend.openai_url), ("CONTEXT", backend.context)):
            text = text.replace("{{" + name + "}}", json.dumps(value))
        if backend.api_key:
            text += 'env_key = "SKILLWEAVE_LLM_API_KEY"\n'
        pending.append((target, text))
        launch = "codex --profile skillweave-local"
        print("Requires current Codex profile-file support and server /v1/responses support. Older servers: upgrade or use Pi/OMP chat completions; no automatic API fallback.")
    elif args.harness == "pi":
        agent_dir = Path(os.environ.get("PI_CODING_AGENT_DIR", home / ".pi" / "agent"))
        provider["apiKey"] = "${SKILLWEAVE_LLM_API_KEY}" if backend.api_key else "local"
        models_path = agent_dir / "models.json"
        settings_path = agent_dir / "settings.json"
        models = merge(load_config(models_path), {"providers": {provider_id: provider}})
        settings = merge(load_config(settings_path), rendered_template("pi-settings.json", values))
        pending.extend(((models_path, json.dumps(models, indent=2) + "\n"), (settings_path, json.dumps(settings, indent=2) + "\n")))
        launch = "pi"
    elif args.harness == "omp":
        agent_dir = Path(os.environ.get("SKILLWEAVE_OMP_AGENT_DIR", home / ".omp" / "agent"))
        target = agent_dir / "models.yml"
        if not target.exists() and (agent_dir / "models.yaml").exists():
            target = agent_dir / "models.yaml"
        if not target.exists() and (agent_dir / "models.json").exists():
            raise ValueError("OMP legacy models.json exists; start OMP once to migrate it to models.yml before model setup")
        if backend.api_key:
            provider.update(apiKey="SKILLWEAVE_LLM_API_KEY", auth="apiKey")
        else:
            provider["auth"] = "none"
        models = merge(load_config(target), {"providers": {provider_id: provider}})
        # JSON is a YAML subset; no parser dependency needed for new files.
        pending.append((target, json.dumps(models, indent=2) + "\n"))
        launch = f"omp --model {provider_id}/{backend.model}"
        print("OMP session defaults and auxiliary model roles are unchanged; inspect modelRoles/retry.fallbackChains before claiming the entire harness is offline.")
    elif args.harness == "openclaw":
        target = Path(os.environ.get("OPENCLAW_CONFIG_PATH", home / ".openclaw" / "openclaw.json"))
        current = load_config(target)
        if backend.backend == "ollama":
            provider_id = "ollama"
            provider.update(baseUrl=backend.base_url, api="ollama")
        provider["apiKey"] = "${SKILLWEAVE_LLM_API_KEY}" if backend.api_key else "local"
        values["PROVIDER"] = provider_id
        addition = rendered_template("openclaw.json", values)
        addition["models"]["providers"][provider_id] = provider
        models_allowlist = current.get("agents", {}).get("defaults", {}).get("models")
        if isinstance(models_allowlist, dict):
            addition["agents"]["defaults"]["models"] = {f"{provider_id}/{backend.model}": {}}
        current = merge(current, addition)
        pending.append((target, json.dumps(current, indent=2) + "\n"))
        launch = "openclaw models status"
        print("Gateway/auth/plugins/tools are preserved. No web plugin installed/enabled. Existing remote tools are not disabled; review them separately for offline use.")
    else:
        if backend.backend != "ollama":
            raise ValueError("Ollama launch mappings cannot use llama.cpp; use setup-pi.sh, setup-omp-model.sh, setup-codex.sh, or setup-openclaw.sh --backend llama.cpp --model ALIAS")
        if backend.base_url != "http://127.0.0.1:11434":
            raise ValueError("Ollama launch mappings store model selections, not server URLs; use a harness-specific setup script for a custom endpoint")
        target = home / ".ollama" / "config.json"
        current = merge(load_config(target), rendered_template("ollama-integrations.json", values))
        pending.append((target, json.dumps(current, indent=2) + "\n"))
        launch = "ollama launch"
    # Parse every affected file before changing any of them.
    if any(path.is_symlink() for path, _ in pending):
        raise ValueError("A target config is a symlink; left untouched")
    for target, text in pending:
        save_config(target, text)
    print(f"Model: {backend.backend}/{backend.model}; endpoint: {backend.base_url}; context budget: {backend.context}")
    print(f"Next: {launch}")
    print("No server started, weights downloaded, or tool capability inferred. Configure the server's actual context to match and smoke-test tool calling before agent use.")
    if backend.backend == "llama.cpp":
        print(f"Server example: llama-server -m /path/to/model.gguf --alias {backend.model} --host 127.0.0.1 --port 8080 -c {backend.context} -np 1 --jinja")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError) as exc:
        print(f"Model setup failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
