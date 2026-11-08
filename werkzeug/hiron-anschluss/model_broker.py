#!/usr/bin/env python3
"""Provider-neutral task routing and evidence-only execution statistics.

The broker selects a capability/cost route. It never calls a provider and it
never promotes a model because of an invented confidence score.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import tempfile
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
REGISTRY = ROOT / "_config" / "models" / "model_registry.json"
ROUTES = ("TOOL", "LOCAL", "FREE_CLOUD", "CHEAP_CLOUD", "STRONG_CODING", "ESCALATE")
DEFAULT_POLICY = {"free_first": True, "strong_after_failures": 2}


def load_registry(path: Path | str = REGISTRY) -> dict:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    # Die Registry benennt ihr Schema unter "$schema" (JSON-Schema-Konvention)
    # und steht seit 29.09.2026 auf v2; frueher hiess der Schluessel "schema"
    # und der Wert endete auf v1. Beide Schreibweisen und beide Fassungen
    # gelten, sonst bricht der Broker an einer reinen Umbenennung ab -- genau
    # das war der Fall (ValueError: invalid model registry).
    schema = data.get("$schema") or data.get("schema")
    if schema not in ("hiron.model-registry.v1", "hiron.model-registry.v2"):
        raise ValueError(f"invalid model registry: unbekanntes Schema {schema!r}")
    if not isinstance(data.get("models"), list):
        raise ValueError("invalid model registry: 'models' ist keine Liste")
    return data


def _strict_score(value: object, name: str) -> int:
    if type(value) is not int or not 1 <= value <= 5:
        raise ValueError(f"{name} must be an integer from 1 to 5")
    return value


def _strict_bool(value: object, name: str) -> bool:
    if type(value) is not bool:
        raise ValueError(f"{name} must be a boolean")
    return value


def _supplied_score(supplied: dict, name: str, default: int) -> int:
    return _strict_score(supplied[name], name) if name in supplied else default


def _supplied_bool(supplied: dict, name: str, default: bool) -> bool:
    return _strict_bool(supplied[name], name) if name in supplied else default


def classify(text: str, supplied: dict | None = None) -> dict:
    """Build an explicit task profile; caller-supplied facts win over heuristics."""
    supplied = supplied or {}
    low = text.lower()
    if "workload" in supplied:
        workload = str(supplied["workload"])
    elif any(word in low for word in ("code", "script", "git", "test", "debug", "fehler")):
        workload = "coding"
    elif any(word in low for word in ("diagnose", "ursache", "unklar", "investigate")):
        workload = "diagnosis"
    elif any(word in low for word in ("copy", "move", "rename", "format", "sortiere")):
        workload = "tool"
    else:
        workload = "editorial"
    complexity_default = 3 if any(word in low for word in ("architecture", "refactor", "security", "parallel", "ursache")) else 1
    risk_default = 4 if any(word in low for word in ("delete", "deploy", "lock", "gitignore", "security", "wache")) else 1
    ambiguity_default = 3 if any(word in low for word in ("unknown", "unclear", "unklar", "ursache", "diagnose")) else 1
    return {
        "workload": workload,
        "complexity": _supplied_score(supplied, "complexity", complexity_default),
        "scope": _supplied_score(supplied, "scope", 2 if len(text) > 900 else 1),
        "context": supplied.get("context", len(text)),
        "context_unit": supplied.get("context_unit", "characters"),
        "output_tokens": supplied.get("output_tokens"),
        "data_class": supplied.get("data_class"),
        "required_tools": supplied.get("required_tools", []),
        "required_capabilities": supplied.get("required_capabilities", [workload]),
        "risk": _supplied_score(supplied, "risk", risk_default),
        "ambiguity": _supplied_score(supplied, "ambiguity", ambiguity_default),
        "verifiability": _supplied_score(supplied, "verifiability", 4),
        "tool_use_required": _supplied_bool(supplied, "tool_use_required", workload in ("coding", "diagnosis")),
        "structured_output_required": _supplied_bool(supplied, "structured_output_required", False),
    }


def _number(value: object) -> bool:
    return type(value) in (int, float) and math.isfinite(value) and value >= 0


def _names(value: object) -> bool:
    return isinstance(value, list) and all(isinstance(x, str) and x for x in value)


def admission_reasons(model: dict, profile: dict, policy: dict) -> list[str]:
    """Fail closed. Metadata must be supplied by a trusted runtime adapter, not a prompt.

    cost_upper_bound is the maximum API charge for this complete attempt,
    including the declared output limit. Cache presence is never readiness.
    """
    reasons = []
    if model.get('provider_ready') is not True:
        reasons.append('provider_not_ready')
    try:
        expiry = datetime.fromisoformat(model['readiness_expires_at'])
        if expiry.tzinfo is None or expiry <= datetime.now(timezone.utc):
            reasons.append('readiness_expired')
    except (KeyError, TypeError, ValueError):
        reasons.append('readiness_unknown')
    cloud = model.get('tier') != 'LOCAL'
    if cloud and policy.get('cloud_allowed') is not True:
        reasons.append('cloud_not_authorized')
    data_class = profile.get('data_class')
    if (not isinstance(data_class, str) or not _names(model.get('data_classes'))
            or not _names(policy.get('allowed_data_classes'))
            or data_class not in model['data_classes'] or data_class not in policy['allowed_data_classes']):
        reasons.append('data_class_not_authorized')
    for field, available in [('required_capabilities', 'capabilities'), ('required_tools', 'tools')]:
        need, have = profile.get(field), model.get(available)
        if not _names(need) or not _names(have) or not set(need).issubset(have):
            reasons.append(field + '_unsupported')
    if (profile.get('tool_use_required') or profile.get('required_tools')) and model.get('tool_use') is not True:
        reasons.append('tool_use_unsupported')
    if profile.get('structured_output_required') and model.get('structured_output') is not True:
        reasons.append('structured_output_unsupported')
    context, output, limit = profile.get('context'), profile.get('output_tokens'), model.get('context_tokens')
    if (profile.get('context_unit') != 'tokens' or type(context) is not int or context < 0
            or type(output) is not int or output <= 0 or type(limit) is not int or limit <= 0):
        reasons.append('token_context_unknown')
    elif context + output > limit:
        reasons.append('context_limit_exceeded')
    if any(type(x) is not int or not 1 <= x <= 5 for x in (model.get('max_risk'), policy.get('max_risk'))):
        reasons.append('risk_limit_unknown')
    elif profile['risk'] > min(model['max_risk'], policy['max_risk']):
        reasons.append('risk_limit_exceeded')
    quota = model.get('quota_remaining')
    if not _number(quota) or quota < 1:
        reasons.append('quota_exhausted_or_unknown')
    cost, ceiling = model.get('cost_upper_bound'), policy.get('max_cost')
    if not _number(cost) or not _number(ceiling):
        reasons.append('cost_bound_unknown')
    elif cost > ceiling:
        reasons.append('budget_exceeded')
    if (not isinstance(policy.get('currency'), str) or len(policy['currency']) != 3
            or model.get('cost_currency') != policy['currency']):
        reasons.append('cost_currency_mismatch')
    if model.get('tier') == 'FREE_CLOUD' and cost != 0:
        reasons.append('free_quota_not_guaranteed')
    return reasons


def _candidate_models(registry: dict, route: str, profile: dict | None = None,
                      policy: dict | None = None) -> list[str]:
    return [model['id'] for model in registry['models']
            if model.get('tier') == route and profile is not None
            and not admission_reasons(model, profile, policy or {})]


def decide(
    text: str,
    supplied: dict | None = None,
    registry: dict | None = None,
    previous_failures: int = 0,
    policy: dict | None = None,
) -> dict:
    """Select a route; provider choice remains a separate registry concern.
    
    HARNES INTEGRATION: If climate_mode=true in supplied, override to ESCALATE
    and mark for Bryson ModelRouter (climate-aware Harnes routing).
    """
    registry = registry or load_registry()
    active_policy = {**DEFAULT_POLICY, **(policy or {})}
    profile = classify(text, supplied)
    
    # HARNES CLIMATE-MODE OVERRIDE (highest priority)
    if supplied and supplied.get("climate_mode") is True:
        profile["climate_mode"] = True
        # Return early with Harnes routing indicator
        # Note: matches standard decide() return schema exactly
        return {
            "profile": profile,
            "route": "ESCALATE",  # Elevation to Harnes
            "candidate_models": [],
            "preferred_route": "ESCALATE",
            "exclusions": {},
            "blocked": True,  # Matches: route == "ESCALATE" → blocked = True
            "reason": "climate_mode=true: routing to Harnes (DeepSeek climate-aware)",
            "verification_required": True,
            "harnes_routed": True,  # ← signals to broker_runtime to use ModelRouter
            "openrouter_allowed": False,
            "policy": "Climate-mode tasks are routed via Bryson ModelRouter to Harnes.",
        }
    
    failure_limit = max(1, int(active_policy["strong_after_failures"]))
    if profile["workload"] == "tool" and profile["complexity"] <= 2 and profile["risk"] <= 2:
        route, reason = "TOOL", "deterministic tool workload with low scope and risk"
    elif profile["workload"] == "coding" and (profile["risk"] >= 4 or profile["complexity"] >= 4):
        route, reason = "STRONG_CODING", "high-risk or high-complexity coding skips weak intermediate tiers"
    elif previous_failures >= failure_limit:
        route, reason = "ESCALATE", f"{previous_failures} recorded failures reached the configured limit {failure_limit}"
    elif profile["risk"] >= 4:
        route, reason = "STRONG_CODING", "high-risk work requires strong reasoning plus verification"
    elif profile["ambiguity"] >= 3 and profile["workload"] in ("coding", "diagnosis"):
        route = "FREE_CLOUD" if active_policy["free_first"] else "CHEAP_CLOUD"
        reason = "ambiguous diagnosis starts on the cheapest allowed capable route and escalates if unresolved"
    elif profile["complexity"] <= 2 and profile["risk"] <= 2:
        route = "LOCAL" if active_policy["free_first"] else "CHEAP_CLOUD"
        reason = "low complexity and risk use the configured budget preference"
    else:
        route, reason = "CHEAP_CLOUD", "moderate work exceeds local policy but does not justify strong coding"
    preferred_route = route
    exclusions = {model.get('id', '<unknown>'): admission_reasons(model, profile, active_policy)
                  for model in registry['models'] if model.get('tier') == route}
    candidates = [] if route in ("TOOL", "ESCALATE") else _candidate_models(registry, route, profile, active_policy)
    if route != "TOOL" and not candidates:
        route, reason = "ESCALATE", reason + "; no eligible model: readiness or admission metadata missing"
    return {
        "profile": profile,
        "route": route,
        "candidate_models": candidates,
        "preferred_route": preferred_route,
        "exclusions": {key: value for key, value in exclusions.items() if value},
        "blocked": route == "ESCALATE",
        "reason": reason,
        "verification_required": profile["risk"] >= 3 or profile["workload"] in ("coding", "diagnosis"),
        "openrouter_allowed": any(model.startswith("openrouter/") for model in candidates),
        "policy": "HIRON selects capability route and budget/risk policy; providers only fulfil an eligible route.",
    }


def routing_hint(text: str, supplied: dict | None = None, policy: dict | None = None) -> dict:
    decision = decide(text, supplied, policy=policy)
    return {
        "workload": decision["profile"]["workload"],
        "tier": decision["route"],
        "route": decision["route"],
        "local_candidate": decision["route"] == "LOCAL",
        "verification": decision["verification_required"],
        "complexity": decision["profile"]["complexity"],
        "risk": decision["profile"]["risk"],
        "suggested_model_at_creation": (decision["candidate_models"] or [None])[0],
        "binding": False,
        "reassess_at_execution": True,
    }


def history_path() -> Path:
    return Path(os.environ.get("LOCALAPPDATA", tempfile.gettempdir())) / "HIRON" / "model-broker" / "execution-history.jsonl"


def _evidence():
    import importlib.util
    path = Path(__file__).with_name("broker_evidence.py")
    spec = importlib.util.spec_from_file_location("broker_evidence", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def record_run(entry: dict, path: Path | str | None = None) -> None:
    """Store only a sealed v2 evidence row. A bare success claim is rejected."""
    if any(key in entry for key in ("confidence", "predicted_success", "estimated_success")):
        raise ValueError("predicted confidence is not execution evidence")
    _evidence().record_run(entry, path)


def _history_rows(path: Path | str | None = None) -> tuple[list[dict], int]:
    target = Path(path or history_path())
    rows, invalid = [], 0
    if not target.exists():
        return rows, invalid
    for line in target.read_text(encoding="utf-8").splitlines():
        try:
            row = _evidence().validate_entry(json.loads(line))
        except (json.JSONDecodeError, ValueError, TypeError, OverflowError):
            invalid += 1
            continue
        rows.append(row)
    return rows, invalid


def history_stats(path: Path | str | None = None) -> dict:
    rows, invalid = _history_rows(path)
    counts = Counter((row.get("workload"), row.get("model"), row.get("route"), row.get("outcome")) for row in rows)
    groups = []
    for workload, model, route in sorted({key[:3] for key in counts}):
        success = counts[workload, model, route, "success"]
        failure = counts[workload, model, route, "failure"]
        total = success + failure
        matching = [row for row in rows if (row.get("workload"), row.get("model"), row.get("route")) == (workload, model, route)]
        actual_costs = [float(row["actual_cost"]) for row in matching if isinstance(row.get("actual_cost"), (int, float))]
        groups.append({
            "workload": workload, "model": model, "route": route, "runs": total,
            "success": success, "failure": failure, "success_rate": (success / total) if total else None,
            "actual_cost_total": sum(actual_costs) if actual_costs else None,
            "cost_complete": False,
        })
    return {"runs": len(rows), "invalid_history_lines": invalid, "by_workload_model": groups}


def usage_recommendations(path: Path | str | None = None, minimum_runs: int = 4) -> list[dict]:
    """Do not price a saving from this history. Matched cohorts live in broker_evidence."""
    rows, _invalid = _history_rows(path)
    if not rows:
        return []
    return [{
        "kind": "controlled_comparison_needed",
        "reason": "unverified or unmatched rows cannot price a saving",
        "automatic_switch": False,
        "runs": len(rows),
        "minimum_runs_is_not_a_threshold": minimum_runs,
    }]


def selftest() -> int:
    def admitted(tier: str, capabilities: list[str], cost: float = 0.1) -> dict:
        return {
            "id": f"fixture/{tier.lower()}",
            "provider": "fixture",
            "tier": tier,
            "provider_ready": True,
            "readiness_expires_at": "2099-01-01T00:00:00+00:00",
            "capabilities": capabilities,
            "tool_use": True,
            "tools": ["lookup"],
            "structured_output": True,
            "context_tokens": 4096,
            "max_risk": 5,
            "data_classes": ["public"],
            "quota_remaining": 2,
            "cost_upper_bound": cost,
            "cost_currency": "EUR",
        }

    registry = {"models": [
        admitted("LOCAL", ["editorial"], 0),
        admitted("FREE_CLOUD", ["diagnosis"], 0),
        admitted("CHEAP_CLOUD", ["editorial"], 0.1),
        admitted("STRONG_CODING", ["coding"], 0.1),
    ]}
    base = {
        "context": 20,
        "context_unit": "tokens",
        "output_tokens": 20,
        "data_class": "public",
        "required_tools": ["lookup"],
        "structured_output_required": True,
    }
    admitting = {
        "cloud_allowed": True,
        "max_cost": 1,
        "currency": "EUR",
        "allowed_data_classes": ["public"],
        "max_risk": 5,
    }
    checks = [
        ("local", decide("mark", {**base, "workload": "editorial"}, registry, policy={**admitting, "free_first": True})["route"] == "LOCAL"),
        ("budget-policy", decide("mark", {**base, "workload": "editorial"}, registry, policy={**admitting, "free_first": False})["route"] == "CHEAP_CLOUD"),
        ("safe-coding", decide("lock", {**base, "workload": "coding", "risk": 4}, registry, policy=admitting)["route"] == "STRONG_CODING"),
        ("ambiguous", decide("diagnose", {**base, "workload": "diagnosis", "ambiguity": 4}, registry, policy={**admitting, "free_first": True})["route"] == "FREE_CLOUD"),
        ("incomplete-registry-escalates", decide("mark", {"workload": "editorial"}, {"models": [{"id": "cached", "tier": "LOCAL"}]})["route"] == "ESCALATE"),
        ("escalation", decide("edit", {"workload": "editorial", "complexity": 3}, previous_failures=2)["route"] == "ESCALATE"),
        ("hint", routing_hint("x")["binding"] is False),
    ]
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "history.jsonl"
        try:
            record_run({"workload": "editorial", "model": "local-x", "route": "LOCAL", "outcome": "success"}, path)
            rejected_bare = False
        except ValueError:
            rejected_bare = True
        checks.append(("bare-success-rejected", rejected_bare and not path.exists()))
        checks.append(("unverified-history-empty", history_stats(path)["runs"] == 0))
        try:
            record_run({"workload": "coding", "model": "x", "route": "LOCAL", "outcome": "success", "confidence": 0.9}, path)
            rejected_prediction = False
        except ValueError:
            rejected_prediction = True
        checks.append(("no-invented-confidence", rejected_prediction))
    for name, ok in checks:
        print(("OK " if ok else "FEHL ") + name)
    print(f"Ran {len(checks)} tests")
    import unittest
    suite = unittest.defaultTestLoader.discover(str(Path(__file__).resolve().parents[1] / "tests"), pattern="test_broker_*.py")
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    return 0 if all(check[1] for check in checks) and result.testsRun > 0 and result.wasSuccessful() else 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--text", default="")
    parser.add_argument("--hint", action="store_true")
    parser.add_argument("--stats", action="store_true")
    parser.add_argument("--recommendations", action="store_true")
    parser.add_argument("--record-json")
    parser.add_argument("--history")
    parser.add_argument("--selbsttest", action="store_true")
    parser.add_argument("--previous-failures", type=int, default=0)
    parser.add_argument("--profile-json")
    parser.add_argument("--policy-json")
    args = parser.parse_args()
    history = Path(args.history) if args.history else None
    if args.selbsttest:
        return selftest()
    if args.record_json:
        record_run(json.loads(args.record_json), history)
        print(json.dumps({"recorded": True}, ensure_ascii=False))
        return 0
    if args.stats:
        print(json.dumps(history_stats(history), ensure_ascii=False, indent=2))
        return 0
    if args.recommendations:
        print(json.dumps(usage_recommendations(history), ensure_ascii=False, indent=2))
        return 0
    profile = json.loads(args.profile_json) if args.profile_json else {}
    policy = json.loads(args.policy_json) if args.policy_json else {}
    output = routing_hint(args.text, profile, policy) if args.hint else decide(
        args.text, profile, previous_failures=args.previous_failures, policy=policy
    )
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
