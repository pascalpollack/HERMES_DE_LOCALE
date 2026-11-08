"""Turn registry metadata into the facts the broker is allowed to trust.

Historical provider_ready, expiry, quota and cost fields are claims in a
snapshot. They are removed before decide(). A live fact is only a local
observation: whether a known runtime binary is on PATH, and whether
127.0.0.1:11434 accepts a TCP connection. That port is the default in the
existing frontdesk tool. No other address is contacted, and no model is called.
"""

from __future__ import annotations

import shutil
import socket

HISTORICAL_NOT_LIVE = (
    "provider_ready",
    "readiness_expires_at",
    "quota_remaining",
    "health_status",
    "availability",
    "cost_upper_bound",
    "cost_per_1m_tokens",
)
BROKER_ROUTES = ("TOOL", "LOCAL", "FREE_CLOUD", "CHEAP_CLOUD", "STRONG_CODING", "ESCALATE")
RUNTIME_NAMES = ("ollama", "llama-server", "litellm", "vllm")
OLLAMA_PROBE = ("127.0.0.1", 11434)


def probe_runtime() -> dict:
    binaries = {name: shutil.which(name) is not None for name in RUNTIME_NAMES}
    listening = False
    try:
        with socket.create_connection(OLLAMA_PROBE, timeout=0.2):
            listening = True
    except OSError:
        listening = False
    return {
        "executables_on_path": binaries,
        "tcp_127_0_0_1_11434": listening,
        "provider_call": False,
    }


def live_registry(registry: dict, observation: dict | None = None) -> dict:
    observation = observation if observation is not None else probe_runtime()
    ollama_ready = bool(
        observation["executables_on_path"].get("ollama") and observation["tcp_127_0_0_1_11434"]
    )
    models = []
    for model in registry.get("models") or []:
        if not isinstance(model, dict):
            continue
        live = {key: value for key, value in model.items() if key not in HISTORICAL_NOT_LIVE}
        local_ollama = model.get("provider") == "custom:ollama" and model.get("tier") == "LOCAL"
        live["provider_ready"] = bool(local_ollama and ollama_ready)
        models.append(live)
    return {"$schema": registry.get("$schema") or registry.get("schema"), "models": models}


def tier_gap(registry: dict) -> list[str]:
    found = []
    for model in registry.get("models") or []:
        tier = model.get("tier") if isinstance(model, dict) else None
        if isinstance(tier, str) and tier not in BROKER_ROUTES and tier not in found:
            found.append(tier)
    return found


def boundaries(registry: dict | None, observation: dict) -> dict:
    return {
        "automated": [
            "PATH probe for ollama, llama-server, litellm, vllm",
            "TCP connect to 127.0.0.1:11434 only",
        ],
        "ignored_historical_fields": list(HISTORICAL_NOT_LIVE),
        "human_required": [
            "cloud_allowed",
            "allowed_data_classes",
            "max_risk",
            "max_cost",
            "currency",
            "whether a local runtime may be installed",
            "a provider adapter base_url, which is absent from these rows",
        ],
        "configured_adapters": [],
        "unknown": [
            "provider_entitlement.consumption",
            "provider_entitlement.remaining",
            "provider_entitlement.reset",
            "admission facts a normal Hermes chat does not carry",
        ],
        "broker_routes": list(BROKER_ROUTES),
        "registry_tiers_not_broker_routes": tier_gap(registry or {}),
        "probe": observation,
    }
