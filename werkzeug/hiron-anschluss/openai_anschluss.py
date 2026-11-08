#!/usr/bin/env python3
"""Loopback OpenAI-chat endpoint in front of the existing HIRON model broker.

Hermes 0.22.7 calls a custom provider at ``<api>/chat/completions`` and
``<api>/models`` (``providers.<name>.api`` ends in ``/v1``, transport
``openai_chat``). This process binds to 127.0.0.1 only. It does not open
another network connection except an optional loopback forward, and it does
not read a Hermes home.

The broker file next to this script is the workshop copy. ``decide`` stays
fail-closed: a stock chat does not carry admission facts, and this process
does not invent quota, readiness, or account names. Provider entitlement is
always reported unknown. ``dispatcher.entscheide`` is not called: that core
routes envelopes to a Hermes CLI process, which is a different contract.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from hmac import compare_digest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import model_broker  # noqa: E402  the unchanged workshop broker


LOCAL_REQUESTS = {"forwarded": 0, "refused": 0}


def _token() -> str:
    return os.environ.get("HIRON_ROUTER_TOKEN", "")


def _registry():
    raw = os.environ.get("HIRON_MODEL_REGISTRY", "").strip()
    if not raw:
        return None
    return model_broker.load_registry(raw)


def _policy():
    raw = os.environ.get("HIRON_POLICY_JSON", "").strip()
    if not raw:
        return None
    return json.loads(Path(raw).read_text(encoding="utf-8"))


def _local_backend() -> str:
    return os.environ.get("HIRON_LOCAL_BACKEND_URL", "").strip().rstrip("/")


def _loopback(url: str) -> bool:
    host = (urlparse(url).hostname or "").lower()
    return host in {"127.0.0.1", "localhost", "::1"}


def _user_text(body: dict) -> str:
    chunks = []
    for message in body.get("messages") or []:
        if not isinstance(message, dict) or message.get("role") != "user":
            continue
        content = message.get("content")
        if isinstance(content, str):
            chunks.append(content)
        elif isinstance(content, list):
            for part in content:
                if isinstance(part, dict) and isinstance(part.get("text"), str):
                    chunks.append(part["text"])
    return "\n".join(chunks)


def _decide(text: str) -> dict:
    registry = _registry()
    if registry is None:
        return {"blocked": True, "route": None, "reason": "registry_absent", "candidate_models": []}
    return model_broker.decide(text, registry=registry, policy=_policy())


def _error(code: str, message: str, status: int) -> tuple[int, dict]:
    return status, {"error": {"message": message, "type": "hiron_anschluss", "code": code}}


def _authorize(header: str) -> bool:
    expected = _token()
    if not expected or not header.startswith("Bearer "):
        return False
    return compare_digest(header[len("Bearer "):], expected)


def _health() -> dict:
    registry = None
    registry_error = ""
    try:
        registry = _registry()
    except Exception as exc:
        registry_error = type(exc).__name__
    return {
        "status": "ok",
        "bind": "127.0.0.1",
        "hermes_contract": "openai_chat",
        "paths": ["/v1/models", "/v1/chat/completions"],
        "registry": "present" if registry else "absent",
        "registry_error": registry_error,
        "provider_entitlement": {
            "consumption": "unknown",
            "remaining": "unknown",
            "reset": "unknown",
            "source": "none",
        },
        "local_usage": {
            "forwarded_requests": LOCAL_REQUESTS["forwarded"],
            "refused_requests": LOCAL_REQUESTS["refused"],
            "note": "counts this process only; not a provider balance",
        },
        "dispatcher": "not_used",
    }


def _models() -> dict:
    registry = _registry()
    data = []
    if registry:
        for model in registry.get("models") or []:
            if isinstance(model, dict) and isinstance(model.get("id"), str):
                data.append({
                    "id": model["id"],
                    "object": "model",
                    "owned_by": str(model.get("provider") or "registry"),
                })
    return {"object": "list", "data": data}


def _refuse(code: str, message: str) -> tuple[int, dict]:
    LOCAL_REQUESTS["refused"] += 1
    return _error(code, message, 409 if code != "registry_absent" else 503)


def _chat(body: dict) -> tuple[int, dict | bytes, str]:
    decision = _decide(_user_text(body))
    if decision.get("reason") == "registry_absent":
        status, payload = _refuse("registry_absent", "Keine Modellregistratur. Es wird kein Konto angenommen.")
        return status, payload, "json"
    if decision.get("blocked") or not decision.get("candidate_models"):
        reasons = []
        for values in (decision.get("exclusions") or {}).values():
            reasons.extend(values)
        code = reasons[0] if reasons else str(decision.get("reason") or "blocked")
        status, payload = _refuse(code, "Der Broker lässt diesen Aufruf nicht zu: " + code)
        return status, payload, "json"
    if decision.get("route") != "LOCAL":
        status, payload = _refuse(
            "cloud_route_not_called",
            "Nur eine zugelassene LOCAL-Route darf einen Loopback-Stub erreichen. Kein externer Aufruf.",
        )
        return status, payload, "json"
    backend = _local_backend()
    if not backend or not _loopback(backend):
        status, payload = _refuse("no_local_backend", "Keine Loopback-Adresse für ein lokales Backend.")
        return status, payload, "json"
    requested = str(body.get("model") or "")
    if requested not in decision["candidate_models"]:
        status, payload = _refuse("model_not_admitted", "Das angeforderte Modell ist nicht in der zugelassenen LOCAL-Liste.")
        return status, payload, "json"
    payload = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        backend + "/v1/chat/completions",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            raw = response.read()
            kind = "stream" if body.get("stream") is True else "json"
    except urllib.error.URLError:
        status, payload = _refuse("local_backend_unreachable", "Das lokale Backend antwortet nicht.")
        return status, payload, "json"
    LOCAL_REQUESTS["forwarded"] += 1
    if kind == "stream":
        return 200, raw, "stream"
    return 200, json.loads(raw.decode("utf-8")), "json"


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("hiron-anschluss " + (fmt % args) + "\n")

    def _send(self, status: int, payload, kind: str) -> None:
        if kind == "stream":
            body = payload if isinstance(payload, bytes) else b""
            content_type = "text/event-stream"
        else:
            body = json.dumps(payload).encode("utf-8")
            content_type = "application/json"
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _authorized(self) -> bool:
        return _authorize(self.headers.get("Authorization", ""))

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path == "/health":
            self._send(200, _health(), "json")
            return
        if not self._authorized():
            self._send(401, _error("unauthorized", "Bearer fehlt oder stimmt nicht.", 401)[1], "json")
            return
        if path == "/v1/models":
            try:
                self._send(200, _models(), "json")
            except Exception:
                self._send(*_error("registry_unreadable", "Die Registratur ist nicht lesbar.", 503), "json")
            return
        self._send(*_error("not_found", "Unbekannter Pfad.", 404), "json")

    def do_POST(self) -> None:  # noqa: N802
        if urlparse(self.path).path != "/v1/chat/completions":
            self._send(*_error("not_found", "Unbekannter Pfad.", 404), "json")
            return
        if not self._authorized():
            self._send(401, _error("unauthorized", "Bearer fehlt oder stimmt nicht.", 401)[1], "json")
            return
        length = int(self.headers.get("Content-Length", "0") or "0")
        if length > 1_000_000:
            self._send(*_error("body_too_large", "Der Körper ist über 1000000 Bytes.", 413), "json")
            return
        try:
            body = json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeError, json.JSONDecodeError):
            self._send(*_error("invalid_json", "Der Körper ist kein JSON-Objekt.", 400), "json")
            return
        if not isinstance(body, dict):
            self._send(*_error("invalid_json", "Der Körper ist kein JSON-Objekt.", 400), "json")
            return
        try:
            status, payload, kind = _chat(body)
        except Exception:
            status, payload, kind = 503, _error("broker_error", "Der Broker hat den Aufruf nicht entschieden.", 503)[1], "json"
            LOCAL_REQUESTS["refused"] += 1
        self._send(status, payload, kind)


def serve(port: int) -> None:
    if not _token():
        raise SystemExit("HIRON_ROUTER_TOKEN fehlt. Es wird nichts gestartet.")
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    host, bound = server.server_address[:2]
    if host != "127.0.0.1":
        raise SystemExit("Bind ist nicht Loopback.")
    sys.stdout.write(json.dumps({"event": "listening", "host": host, "port": bound}) + "\n")
    sys.stdout.flush()
    server.serve_forever()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Loopback-Anschluss für Hermes openai_chat")
    parser.add_argument("--port", type=int, default=0)
    args = parser.parse_args(argv)
    if args.port < 0 or args.port > 65535:
        return 2
    serve(args.port)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
