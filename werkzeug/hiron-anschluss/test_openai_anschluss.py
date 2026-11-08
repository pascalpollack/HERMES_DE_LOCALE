#!/usr/bin/env python3
"""Hermes-shaped requests through the real broker. No injected admission."""

from __future__ import annotations

import json
import os
import threading
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path

import aufnahme
import openai_anschluss as anschluss

REGISTRY = Path(__file__).resolve().parent / "registry-metadata-v2.json"


def _check(cond: bool, text: str) -> None:
    if not cond:
        raise SystemExit("FAIL: " + text)


def _start():
    server = ThreadingHTTPServer(("127.0.0.1", 0), anschluss.Handler)
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
            return response.status, response.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


def main() -> int:
    historical = json.loads(REGISTRY.read_text(encoding="utf-8"))
    _check(historical["$schema"] == "hiron.model-registry.v2", "schema")
    _check(len(historical["models"]) == 4, "four rows")
    _check(all("base_url" not in model and "url" not in model for model in historical["models"]), "no endpoint")
    observation = aufnahme.probe_runtime()
    live = aufnahme.live_registry(historical, observation)
    by_id = {model["id"]: model for model in live["models"]}
    qwen = by_id["hiron-qwen:7b-64k"]
    _check("quota_remaining" not in qwen, "historical quota removed")
    _check("readiness_expires_at" not in qwen, "historical expiry removed")
    _check(qwen["provider_ready"] is False or (
        observation["executables_on_path"]["ollama"] and observation["tcp_127_0_0_1_11434"]
    ), "ready only from a live probe")
    gap = aufnahme.tier_gap(historical)
    _check("CLOUD_PREMIUM" in gap and "CLOUD_STANDARD" in gap and "CLOUD_ECONOMY" in gap, "tier gap")

    decision = anschluss.model_broker.decide("ping", registry=live)
    _check(decision["blocked"] is True, "normal text is not admitted")
    _check(decision["candidate_models"] == [], "no candidate")
    reasons = decision["exclusions"].get("hiron-qwen:7b-64k") or []
    _check("provider_not_ready" in reasons or "quota_exhausted_or_unknown" in reasons, "fail closed: " + ",".join(reasons))

    os.environ["HIRON_ROUTER_TOKEN"] = "synthetic-token"
    os.environ.pop("HIRON_MODEL_REGISTRY", None)
    os.environ.pop("HIRON_POLICY_JSON", None)
    os.environ.pop("HIRON_LOCAL_BACKEND_URL", None)
    anschluss.LOCAL_REQUESTS["forwarded"] = 0
    anschluss.LOCAL_REQUESTS["refused"] = 0
    server = _start()
    port = server.server_address[1]
    try:
        status, raw = _call(port, "/v1/models", "nope")
        _check(status == 401, "auth")
        status, raw = _call(port, "/v1/chat/completions", "synthetic-token", {
            "model": "hiron-qwen:7b-64k",
            "messages": [{"role": "user", "content": "ping"}],
            "stream": True,
        })
        _check(status == 503 and json.loads(raw)["error"]["code"] == "registry_absent", "missing registry")
        os.environ["HIRON_MODEL_REGISTRY"] = str(REGISTRY)
        status, raw = _call(port, "/v1/chat/completions", "synthetic-token", {
            "model": "hiron-qwen:7b-64k",
            "messages": [{"role": "user", "content": "ping"}],
            "stream": True,
        })
        body = json.loads(raw)
        _check(status == 409, "refused on the production path")
        _check(body["error"]["code"] in reasons or body["error"]["code"] == "provider_not_ready", body["error"]["code"])
        _check("synthetic-token" not in raw.decode("utf-8"), "no token leak")
        _check(body["diagnosis"]["exclusions"].get("hiron-qwen:7b-64k"), "diagnosis names the row")
        _check(anschluss.LOCAL_REQUESTS["forwarded"] == 0, "nothing forwarded")
        status, raw = _call(port, "/health", "")
        health = json.loads(raw)
        _check(health["provider_entitlement"]["remaining"] == "unknown", "entitlement unknown")
        _check(health["boundaries"]["configured_adapters"] == [], "no invented adapter")
        _check("CLOUD_PREMIUM" in health["boundaries"]["registry_tiers_not_broker_routes"], "health shows the gap")
        _check(health["local_usage"]["forwarded_requests"] == 0, "no local completion counted")
    finally:
        server.shutdown()
    print("OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
