"""Collect every enabled provider into one JSON document."""

from __future__ import annotations

import datetime as dt
import logging
import time
from typing import Any, Iterable, Optional

from . import google, opencode, openrouter, paths, state as state_mod, util

log = logging.getLogger(__name__)

DEFAULT_ORDER = ("opencode", "google_ai", "openrouter")
SCHEMA_VERSION = 1


def _fallback_snapshot(provider_id: str, error: str, previous: Optional[dict[str, Any]]) -> dict[str, Any]:
    if previous and previous.get("available"):
        stale = dict(previous)
        stale["status"] = "warning"
        stale["error"] = error
        return stale
    name = {"opencode": "OpenCode Go", "google_ai": "Google AI Pro", "openrouter": "OpenRouter"}.get(
        provider_id, provider_id
    )
    category = "token_and_cost" if provider_id == "openrouter" else "quota"
    return {
        "id": provider_id,
        "name": name,
        "category": category,
        "plan_name": name,
        "available": False,
        "status": "unknown",
        "error": error,
        "primary_percent": 0.0,
        "metrics": {},
        "rows": [],
        "billing": {"date_string": "", "days": 0},
        "trend": {
            "today_spend_usd": 0.0,
            "today_tokens": 0,
            "yesterday_spend_usd": 0.0,
            "yesterday_tokens": 0,
            "last_30_days_spend_usd": 0.0,
            "last_30_days_tokens": 0,
            "daily_bars": [0.0] * 30,
            "daily_points": [],
            "daily_avg_spend_usd": 0.0,
            "daily_avg_tokens": 0,
            "peak_label": "",
            "peak_tokens": 0,
            "recent_log": "",
            "unit": "steps" if provider_id == "google_ai" else "tokens",
            "cost_available": provider_id != "google_ai",
        },
        "updated_at": util.now_utc().isoformat(),
    }


def _normalize_enabled(enabled: Optional[Iterable[str]]) -> Optional[set[str]]:
    if enabled is None:
        return None
    return {item.strip() for item in enabled if item and item.strip()}


def collect(
    *,
    enabled: Optional[Iterable[str]] = None,
    korean: bool = False,
    billing_day: int = 0,
    agy_max_age: int = 30 * 60,
    now: Optional[dt.datetime] = None,
    write_cache: bool = True,
) -> dict[str, Any]:
    """Run the selected providers and return the extension payload.

    ``enabled=None`` probes every provider (useful from the CLI).
    """

    started = time.time()
    current = now or util.now_utc()
    cached = state_mod.load_state()
    internal = cached.get("internal") if isinstance(cached.get("internal"), dict) else {}

    selected = _normalize_enabled(enabled)
    providers: dict[str, Any] = {}

    tasks = list(DEFAULT_ORDER) if selected is None else [pid for pid in DEFAULT_ORDER if pid in selected]

    for provider_id in tasks:
        previous = state_mod.provider_cache(cached, provider_id)
        try:
            if provider_id == "opencode":
                snapshot = opencode.fetch_snapshot(korean=korean, previous=previous, now=current)
            elif provider_id == "google_ai":
                snapshot = google.fetch_snapshot(
                    korean=korean,
                    billing_day=billing_day,
                    previous=previous,
                    internal=internal,
                    now=current,
                )
            elif provider_id == "openrouter":
                snapshot = openrouter.fetch_snapshot(korean=korean, previous=previous, now=current)
            else:  # pragma: no cover - guarded by DEFAULT_ORDER
                continue
        except Exception as exc:  # never let one provider break the payload
            log.exception("provider %s failed", provider_id)
            snapshot = _fallback_snapshot(provider_id, "internal_error", previous)
            log.debug("fallback caused by: %s", exc)

        providers[provider_id] = snapshot

    output = {
        "schema": SCHEMA_VERSION,
        "generated_at": current.timestamp(),
        "generated_at_iso": current.isoformat(),
        "duration_ms": int((time.time() - started) * 1000),
        "korean": korean,
        "providers": providers,
    }

    if write_cache:
        # A partial run (e.g. only the providers the user enabled) must not
        # erase the snapshots of the others; keep them for the next refresh.
        previous_providers = cached.get("providers")
        merged = dict(previous_providers) if isinstance(previous_providers, dict) else {}
        merged.update(providers)
        cached["providers"] = merged
        cached["internal"] = internal
        try:
            state_mod.save_state(cached)
        except OSError as exc:  # cache failures must not break the UI
            log.warning("could not write cache: %s", exc)

    return output


def cached_payload() -> dict[str, Any]:
    """Return the previous payload without touching the network."""

    cached = state_mod.load_state()
    return {
        "schema": SCHEMA_VERSION,
        "generated_at": float(cached.get("generated_at") or 0.0),
        "providers": cached.get("providers") or {},
        "cached": True,
        "cache_path": str(paths.state_file()),
    }
