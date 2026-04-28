#!/usr/bin/env python3
"""Smoke-test LLM API endpoints without printing secrets.

The script intentionally uses only the Python standard library so it can run on a
fresh machine after cloning this repository.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class Target:
    name: str
    protocol: str
    model: str
    base_url_env: str
    api_key_env: str
    default_base_url: str
    max_tokens: int = 32
    list_models: bool = True


TARGETS: list[Target] = [
    Target(
        name="kimi-k2.7",
        protocol="anthropic_messages",
        model="kimi-k2.7",
        base_url_env="KIMI_BASE_URL",
        api_key_env="KIMI_API_KEY",
        default_base_url="https://llm2api.owlia.dev",
        list_models=False,
    ),
    Target(
        name="qwen3.6-27b",
        protocol="openai_chat",
        model="Qwen/Qwen3.6-27B",
        base_url_env="QWEN_BASE_URL",
        api_key_env="QWEN_API_KEY",
        default_base_url="https://llm2api.owlia.dev/v1",
    ),
    Target(
        name="gemma-4",
        protocol="openai_chat",
        model="gemma-4-31b",
        base_url_env="GEMMA_BASE_URL",
        api_key_env="GEMMA_API_KEY",
        default_base_url="https://llm2api.owlia.dev/v1",
    ),
    Target(
        name="llama-3.1",
        protocol="openai_chat",
        model="llama-3.1",
        base_url_env="LLAMA_BASE_URL",
        api_key_env="LLAMA_API_KEY",
        default_base_url="https://llm2api.owlia.dev/v1",
    ),
    Target(
        name="gpt-oss",
        protocol="openai_chat",
        model="gpt-oss",
        base_url_env="GPT_OSS_BASE_URL",
        api_key_env="GPT_OSS_API_KEY",
        default_base_url="https://llm2api.owlia.dev/v1",
        max_tokens=128,
    ),
]


class HttpResult(dict):
    pass


def load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def env_first(*names: str) -> tuple[str | None, str | None]:
    for name in names:
        value = os.environ.get(name)
        if value:
            return name, value
    return None, None


def request_json(url: str, *, headers: dict[str, str], payload: dict[str, Any] | None, timeout: int) -> HttpResult:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST" if payload is not None else "GET")
    started = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8", "replace")
            return HttpResult(status="ok", http_status=resp.status, elapsed_s=round(time.monotonic() - started, 2), body=parse_jsonish(body), raw=body[:500])
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        return HttpResult(status="http_error", http_status=exc.code, elapsed_s=round(time.monotonic() - started, 2), error=body[:500])
    except Exception as exc:  # noqa: BLE001 - smoke test should report all failures compactly
        return HttpResult(status="error", elapsed_s=round(time.monotonic() - started, 2), error=f"{type(exc).__name__}: {exc}")


def parse_jsonish(text: str) -> Any:
    try:
        return json.loads(text)
    except Exception:
        return text


def normalize_base_url(value: str, protocol: str) -> str:
    """Normalize relay base URLs for OpenAI-compatible vs Anthropic paths."""
    base = value.rstrip("/")
    if protocol == "openai_chat" and not base.endswith("/v1"):
        return f"{base}/v1"
    if protocol == "anthropic_messages" and base.endswith("/v1"):
        return base[:-3]
    return base


def content_from_openai(body: Any) -> str:
    try:
        return body["choices"][0]["message"]["content"] or ""
    except Exception:
        return ""


def content_from_anthropic(body: Any) -> str:
    try:
        parts = body.get("content", [])
        return "".join(p.get("text", "") for p in parts if isinstance(p, dict))
    except Exception:
        return ""


def run_target(target: Target, timeout: int) -> dict[str, Any]:
    shared_key_env, shared_key = env_first("LLM2API_API_KEY", "OPENAI_API_KEY")
    key_env, key = env_first(target.api_key_env, *( [shared_key_env] if shared_key_env else []))
    if not key and shared_key:
        key_env, key = shared_key_env, shared_key

    base_url = os.environ.get(target.base_url_env) or os.environ.get("LLM2API_BASE_URL") or target.default_base_url
    base_url = normalize_base_url(base_url, target.protocol)

    result: dict[str, Any] = {
        "name": target.name,
        "protocol": target.protocol,
        "model": target.model,
        "base_url": base_url,
        "base_url_env": target.base_url_env if os.environ.get(target.base_url_env) else ("LLM2API_BASE_URL" if os.environ.get("LLM2API_BASE_URL") else "default"),
        "api_key_env": key_env or target.api_key_env,
    }

    if not key:
        result.update(status="skipped", reason=f"missing API key env: {target.api_key_env} or LLM2API_API_KEY/OPENAI_API_KEY")
        return result

    if target.protocol == "openai_chat":
        headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
        if target.list_models:
            models = request_json(f"{base_url}/models", headers=headers, payload=None, timeout=timeout)
            result["models_check"] = summarize_models(models, target.model)
        payload = {
            "model": target.model,
            "messages": [{"role": "user", "content": "Reply with only: ok"}],
            "temperature": 0,
            "max_tokens": target.max_tokens,
        }
        chat = request_json(f"{base_url}/chat/completions", headers=headers, payload=payload, timeout=timeout)
        content = content_from_openai(chat.get("body")) if chat.get("status") == "ok" else ""
        result["chat_check"] = summarize_chat(chat, content)
        result["status"] = "passed" if result["chat_check"]["ok"] else "failed"
        return result

    if target.protocol == "anthropic_messages":
        headers = {"x-api-key": key, "anthropic-version": "2023-06-01", "Content-Type": "application/json"}
        payload = {
            "model": target.model,
            "max_tokens": target.max_tokens,
            "temperature": 0,
            "messages": [{"role": "user", "content": "Reply with only: ok"}],
        }
        msg = request_json(f"{base_url}/v1/messages", headers=headers, payload=payload, timeout=timeout)
        content = content_from_anthropic(msg.get("body")) if msg.get("status") == "ok" else ""
        result["message_check"] = summarize_chat(msg, content)
        if isinstance(msg.get("body"), dict):
            result["observed_model"] = msg["body"].get("model")
        result["status"] = "passed" if result["message_check"]["ok"] else "failed"
        return result

    result.update(status="failed", reason=f"unknown protocol: {target.protocol}")
    return result


def summarize_models(resp: HttpResult, expected_model: str) -> dict[str, Any]:
    summary: dict[str, Any] = {"status": resp.get("status"), "http_status": resp.get("http_status"), "elapsed_s": resp.get("elapsed_s")}
    if resp.get("status") != "ok":
        summary["error"] = resp.get("error")
        summary["ok"] = False
        return summary
    body = resp.get("body")
    ids: list[str] = []
    items = body.get("data", []) if isinstance(body, dict) else body if isinstance(body, list) else []
    for item in items:
        if isinstance(item, dict):
            mid = item.get("id") or item.get("name")
            if mid:
                ids.append(str(mid))
        elif item:
            ids.append(str(item))
    summary["model_count"] = len(ids)
    summary["expected_model_found"] = expected_model in ids
    summary["sample_models"] = ids[:10]
    summary["ok"] = True
    return summary


def summarize_chat(resp: HttpResult, content: str) -> dict[str, Any]:
    summary: dict[str, Any] = {"status": resp.get("status"), "http_status": resp.get("http_status"), "elapsed_s": resp.get("elapsed_s")}
    if resp.get("status") != "ok":
        summary["error"] = resp.get("error")
        summary["ok"] = False
        return summary
    summary["content_preview"] = content[:120]
    summary["ok"] = "ok" in content.lower()
    return summary


def markdown(results: list[dict[str, Any]]) -> str:
    lines = ["| target | status | model | base_url | detail |", "|---|---|---|---|---|"]
    for r in results:
        detail = r.get("reason", "")
        check = r.get("chat_check") or r.get("message_check") or {}
        if check:
            detail = f"HTTP {check.get('http_status', '-')}, {check.get('elapsed_s', '-')}s"
            if not check.get("ok"):
                detail += f", {str(check.get('error', 'no ok content'))[:80]}"
        lines.append(f"| {r['name']} | {r.get('status')} | `{r['model']}` | `{r['base_url']}` | {detail} |")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", default=str(ROOT / ".env"), help="dotenv file to load before testing")
    parser.add_argument("--target", action="append", choices=[t.name for t in TARGETS], help="target(s) to run; default: all")
    parser.add_argument("--timeout", type=int, default=90)
    parser.add_argument("--json", action="store_true", help="print JSON instead of Markdown")
    args = parser.parse_args()

    load_dotenv(Path(args.env_file))
    selected = [t for t in TARGETS if not args.target or t.name in args.target]
    results = [run_target(t, args.timeout) for t in selected]
    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
    else:
        print(markdown(results))
    return 0 if all(r.get("status") in {"passed", "skipped"} for r in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
