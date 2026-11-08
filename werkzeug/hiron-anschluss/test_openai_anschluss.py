#!/usr/bin/env python3
"""Synthetic checks for the loopback adapter. No Hermes home and no paid call."""

from __future__ import annotations

import json
import os
import threading
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import openai_anschluss as anschluss


def _check(cond: bool, text: str) -> None:
    if not cond:
        raise SystemExit("FAIL: " + text)


class Stub(BaseHTTPRequestHandler):
    seen = []

    def log_message(self, fmt, *args):
        return

    def do_POST(self):  # noqa: N802
        length = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(length).decode("utf-8"))
        Stub.seen.append({"path": self.path, "stream": body.get("stream"), "model": body.get("model")})
        if body.get("stream") is True:
            payload = (
                b'data: {"choices":[{"delta":{"content":"synthetisch"}}]}\n\n'
                b"data: [DONE]\n\n"
            )
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        raw = json.dumps({
            "id": "stub",
            "object": "chat.completion",
            "choices": [{"message": {"role": "assistant", "content": "synthetisch"}}],
        }).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)


def _start(handler, port=0):
    server = ThreadingHTTPServer(("127.0.0.1", port), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def _call(port, path, token, body=None):
    data = None if body is None else json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        f"http://127.0.0.1:{port}{path}",
        data=data,
        method="GET" if body is None else "POST",
        headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            raw = response.read()
            return response.status, raw
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


def _fixture(root: Path):
    expiry = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
    registry = {
        "$schema": "hiron.model-registry.v2",
        "models": [{
            "id": "synthetic-local",
            "provider": "stub",
            "tier": "LOCAL",
            "provider_ready": True,
            "readiness_expires_at": expiry,
            "data_classes": ["synthetic"],
            "capabilities": ["editorial"],
            "tools": [],
            "tool_use": False,
            "structured_output": False,
            "context_tokens": 1000,
            "max_risk": 2,
            "quota_remaining": 1,
            "cost_upper_bound": 0,
            "cost_currency": "XXX",
        }],
    }
    policy = {
        "free_first": True,
        "strong_after_failures": 2,
        "allowed_data_classes": ["synthetic"],
        "max_risk": 2,
        "max_cost": 0,
        "currency": "XXX",
    }
    registry_path = root / "registry.json"
    policy_path = root / "policy.json"
    registry_path.write_text(json.dumps(registry), encoding="utf-8")
    policy_path.write_text(json.dumps(policy), encoding="utf-8")
    return registry_path, policy_path


def main() -> int:
    os.environ["HIRON_ROUTER_TOKEN"] = "synthetic-token"
    os.environ.pop("HIRON_MODEL_REGISTRY", None)
    os.environ.pop("HIRON_POLICY_JSON", None)
    os.environ.pop("HIRON_LOCAL_BACKEND_URL", None)
    anschluss.LOCAL_REQUESTS["forwarded"] = 0
    anschluss.LOCAL_REQUESTS["refused"] = 0
    _check(anschluss._loopback("http://127.0.0.1:9/v1"), "loopback")
    _check(not anschluss._loopback("http://example.invalid/v1"), "public host refused")

    server = _start(anschluss.Handler)
    port = server.server_address[1]
    status, raw = _call(port, "/health", "")
    health = json.loads(raw)
    _check(status == 200, "health")
    _check(health["provider_entitlement"]["remaining"] == "unknown", "quota unknown")
    _check(health["registry"] == "absent", "no invented registry")
    status, raw = _call(port, "/v1/models", "wrong")
    _check(status == 401, "models reject a bad token")
    status, raw = _call(port, "/v1/models", "synthetic-token")
    _check(json.loads(raw)["data"] == [], "empty catalog")
    status, raw = _call(port, "/v1/chat/completions", "synthetic-token", {
        "model": "synthetic-local",
        "messages": [{"role": "user", "content": "ping"}],
    })
    _check(status == 503 and json.loads(raw)["error"]["code"] == "registry_absent", "no registry")

    root = Path(os.environ.get("TMPDIR", "/tmp")) / "hiron-anschluss-test"
    root.mkdir(parents=True, exist_ok=True)
    registry_path, policy_path = _fixture(root)
    os.environ["HIRON_MODEL_REGISTRY"] = str(registry_path)
    os.environ["HIRON_POLICY_JSON"] = str(policy_path)
    status, raw = _call(port, "/v1/chat/completions", "synthetic-token", {
        "model": "synthetic-local",
        "messages": [{"role": "user", "content": "ping"}],
    })
    blocked = json.loads(raw)
    _check(status == 409, "stock chat is not admitted: " + blocked["error"]["code"])
    _check(blocked["error"]["code"] != "ok", "refusal is explicit")
    _check("synthetic-token" not in raw.decode("utf-8"), "token not in the error")

    # The fixture's admission facts are not in a Hermes chat body. Supply them
    # only inside this test by calling decide the way a complete adapter input
    # would, then prove the HTTP forward still requires a loopback stub.
    text = "ping"
    supplied = {
        "workload": "editorial",
        "complexity": 1,
        "scope": 1,
        "context": 10,
        "context_unit": "tokens",
        "output_tokens": 10,
        "data_class": "synthetic",
        "required_tools": [],
        "required_capabilities": ["editorial"],
        "risk": 1,
        "ambiguity": 1,
        "verifiability": 4,
        "tool_use_required": False,
        "structured_output_required": False,
    }
    decision = anschluss.model_broker.decide(
        text, supplied, registry=json.loads(registry_path.read_text(encoding="utf-8")), policy=json.loads(policy_path.read_text(encoding="utf-8"))
    )
    _check(decision["route"] == "LOCAL" and "synthetic-local" in decision["candidate_models"], "fixture can be admitted")
    os.environ["HIRON_LOCAL_BACKEND_URL"] = "http://127.0.0.1:9"
    # Monkeypatch the chat path's text classification by using a local wrapper:
    # the HTTP handler calls decide(text) without supplied facts, so a normal
    # Hermes body stays blocked. The forward is tested through _chat after
    # substituting decide for this fixture only.
    original = anschluss._decide
    anschluss._decide = lambda _text: decision
    try:
        status, raw = _call(port, "/v1/chat/completions", "synthetic-token", {
            "model": "synthetic-local",
            "messages": [{"role": "user", "content": "ping"}],
            "stream": True,
        })
        _check(json.loads(raw)["error"]["code"] == "local_backend_unreachable", "dead loopback is an error")
        stub = _start(Stub)
        os.environ["HIRON_LOCAL_BACKEND_URL"] = f"http://127.0.0.1:{stub.server_address[1]}"
        status, raw = _call(port, "/v1/chat/completions", "synthetic-token", {
            "model": "synthetic-local",
            "messages": [{"role": "user", "content": "ping"}],
            "stream": True,
        })
        _check(status == 200 and b"data: [DONE]" in raw, "stream reaches the stub")
        _check(Stub.seen[-1]["model"] == "synthetic-local", "model id forwarded")
        status, raw = _call(port, "/health", "")
        health = json.loads(raw)
        _check(health["provider_entitlement"]["consumption"] == "unknown", "entitlement stays unknown")
        _check(health["local_usage"]["forwarded_requests"] == 1, "local count is local")
        cloud = dict(decision)
        cloud["route"] = "CHEAP_CLOUD"
        anschluss._decide = lambda _text: cloud
        before = len(Stub.seen)
        status, raw = _call(port, "/v1/chat/completions", "synthetic-token", {
            "model": "synthetic-local",
            "messages": [{"role": "user", "content": "ping"}],
        })
        _check(json.loads(raw)["error"]["code"] == "cloud_route_not_called", "cloud is not called")
        _check(len(Stub.seen) == before, "stub saw no cloud request")
    finally:
        anschluss._decide = original
        server.shutdown()
    print("OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
