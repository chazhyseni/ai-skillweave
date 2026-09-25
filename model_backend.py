"""Explicit local inference configuration shared by extraction and harness setup."""

import ipaddress
import json
import math
import os
from dataclasses import dataclass
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener


class BackendError(RuntimeError):
    """Inference failed; callers must not record a successful extraction."""


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise BackendError("Inference endpoint redirected; configure the final trusted URL explicitly")


@dataclass(frozen=True)
class ModelBackend:
    backend: str = "ollama"
    model: str = "qwen3.5:4b"
    base_url: str = "http://127.0.0.1:11434"
    timeout: float = 600
    context: int = 16384
    max_tokens: int = 4096
    api_key: str = ""
    allow_remote: bool = False

    def __post_init__(self):
        if self.backend not in ("ollama", "llama.cpp"):
            raise ValueError("Backend must be ollama or llama.cpp")
        if not self.model.strip() or any(ord(c) < 32 for c in self.model):
            raise ValueError("Set an explicit model name (llama.cpp: use llama-server --alias NAME)")
        parts = urlsplit(self.base_url)
        if parts.scheme not in ("http", "https") or not parts.hostname:
            raise ValueError("Base URL must be an absolute http:// or https:// URL")
        if parts.username or parts.password or parts.query or parts.fragment:
            raise ValueError("Base URL must not contain credentials, a query, or a fragment")
        if parts.port == 0:
            raise ValueError("Base URL port must be between 1 and 65535")
        try:
            local = parts.hostname == "localhost" or ipaddress.ip_address(parts.hostname).is_loopback
        except ValueError:
            local = False
        if not self.allow_remote and (not local or "cloud" in self.model.lower()):
            raise ValueError("Remote endpoints/cloud models require explicit --allow-remote (extractor: --llm-allow-remote); conversation data may leave this machine")
        if not math.isfinite(self.timeout) or self.timeout <= 0:
            raise ValueError("Timeout must be a positive finite number")
        if self.context <= 0 or self.max_tokens <= 0 or self.max_tokens >= self.context:
            raise ValueError("Context must be positive and larger than max-tokens")
        if self.backend == "ollama" and parts.path.rstrip("/").endswith(("/v1", "/api")):
            raise ValueError("Ollama base URL is the server root, not /v1 or /api")
        if self.backend == "llama.cpp" and not parts.path.rstrip("/").endswith("/v1"):
            raise ValueError("llama.cpp base URL must end in /v1 (for example http://127.0.0.1:8080/v1)")

    @property
    def openai_url(self):
        return self.base_url.rstrip("/") + ("/v1" if self.backend == "ollama" else "")

    def complete(self, prompt: str, verbose: bool = False) -> str:
        if self.backend == "ollama":
            url = self.base_url.rstrip("/") + "/api/generate"
            payload = {
                "model": self.model, "prompt": prompt, "stream": False, "think": False,
                "options": {"temperature": 0.3, "num_ctx": self.context, "num_predict": self.max_tokens},
            }
        else:
            url = self.openai_url + "/chat/completions"
            payload = {
                "model": self.model, "messages": [{"role": "user", "content": prompt}],
                "stream": False, "temperature": 0.3, "max_tokens": self.max_tokens,
                "chat_template_kwargs": {"enable_thinking": False},
            }
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = "Bearer " + self.api_key
        request = Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
        # No proxy environment inheritance or redirect can silently export local history.
        opener = build_opener(ProxyHandler({}), _NoRedirect())
        try:
            with opener.open(request, timeout=self.timeout) as response:
                data = json.load(response)
        except HTTPError as exc:
            raise BackendError(f"{self.backend}/{self.model} HTTP {exc.code} at {url}; verify model, server/API version and credentials (no fallback attempted)") from exc
        except (URLError, OSError, ValueError) as exc:
            raise BackendError(f"{self.backend} request failed at {url}: {type(exc).__name__}; start the server/check URL and timeout (no fallback attempted)") from exc
        if not isinstance(data, dict) or data.get("error"):
            raise BackendError(f"{self.backend} returned an error or invalid response object")
        try:
            if self.backend == "ollama":
                text = data["response"]
                reason = data.get("done_reason")
                if data.get("done") is not True:
                    raise BackendError("Ollama returned an incomplete non-streaming response")
            else:
                choice = data["choices"][0]
                text = choice["message"]["content"]
                reason = choice.get("finish_reason")
            if reason == "length":
                raise BackendError("Model response truncated; increase max-tokens/context or use a smaller batch")
            if self.backend == "llama.cpp" and reason != "stop":
                raise BackendError(f"llama.cpp completion did not finish normally (finish_reason={reason!r})")
            if not isinstance(text, str) or not text.strip():
                raise BackendError("Model returned no text; check model chat template/thinking settings and output budget")
        except (KeyError, IndexError, TypeError) as exc:
            raise BackendError(f"{self.backend} returned a malformed completion response") from exc
        if verbose:
            print(f"  [LLM-OK] {self.backend}/{self.model}: {len(text)} characters")
        return text.strip()


def add_backend_arguments(parser, prefix=""):
    """Setup uses --backend; extraction uses --llm-backend. Environment is shared."""
    for name, kwargs in (
        ("backend", {"choices": ("ollama", "llama.cpp"), "help": "Inference backend (default: ollama)"}),
        ("model", {"help": "Ollama tag or explicit llama-server model alias"}),
        ("base-url", {"help": "Ollama root URL or llama.cpp /v1 URL"}),
        ("timeout", {"type": float, "help": "HTTP timeout in seconds (default: 600)"}),
        ("context", {"type": int, "help": "Actual server context budget (default: 16384)"}),
        ("max-tokens", {"type": int, "help": "Output budget (default: 4096)"}),
        ("allow-remote", {"action": "store_true", "default": None, "help": "Explicitly allow data to leave this machine"}),
    ):
        parser.add_argument("--" + prefix + name, dest="backend_" + name.replace("-", "_"), **kwargs)


def backend_from_args(args):
    def setting(name, default=None):
        value = getattr(args, "backend_" + name, None)
        return value if value is not None else os.environ.get("SKILLWEAVE_LLM_" + name.upper(), default)

    backend = setting("backend", "ollama")
    model = setting("model", "qwen3.5:4b" if backend == "ollama" else "")
    return ModelBackend(
        backend=backend, model=model,
        base_url=setting("base_url", "http://127.0.0.1:11434" if backend == "ollama" else "http://127.0.0.1:8080/v1").rstrip("/"),
        timeout=float(setting("timeout", 600)), context=int(setting("context", 16384)),
        max_tokens=int(setting("max_tokens", 4096)), api_key=os.environ.get("SKILLWEAVE_LLM_API_KEY", ""),
        allow_remote=str(setting("allow_remote", "false")).lower() in ("1", "true", "yes"),
    )
