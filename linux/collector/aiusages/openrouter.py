"""OpenRouter balance, spend and token counters."""

from __future__ import annotations

import datetime as dt
import logging
from concurrent.futures import ThreadPoolExecutor
from typing import Any, Optional

from . import secrets, trend as trend_mod, util
from .httpclient import request_json

log = logging.getLogger(__name__)

CREDITS_URL = "https://openrouter.ai/api/v1/credits"
KEY_URL = "https://openrouter.ai/api/v1/key"
ACTIVITY_URL = "https://openrouter.ai/api/v1/activity"


def _number(value: Any) -> Optional[float]:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return None
    return None


def _request(url: str, key: str):
    return request_json(
        url,
        headers={"Authorization": f"Bearer {key}", "Accept": "application/json"},
        timeout=6.0,
    )


def parse_credits(payload: Any) -> Optional[float]:
    if not isinstance(payload, dict):
        return None
    data = payload.get("data")
    if not isinstance(data, dict):
        return None
    total = _number(data.get("total_credits")) or 0.0
    usage = _number(data.get("total_usage")) or 0.0
    return max(0.0, total - usage)


def parse_key_info(payload: Any) -> Optional[dict[str, Any]]:
    if not isinstance(payload, dict):
        return None
    data = payload.get("data")
    if not isinstance(data, dict):
        return None
    return {
        "usage_daily": _number(data.get("usage_daily")) or 0.0,
        "usage_weekly": _number(data.get("usage_weekly")) or 0.0,
        "usage_monthly": _number(data.get("usage_monthly")) or 0.0,
        "usage_total": _number(data.get("usage")) or 0.0,
        "prompt_tokens": int(_number(data.get("prompt_tokens")) or 0),
        "completion_tokens": int(_number(data.get("completion_tokens")) or 0),
    }


def parse_activity(payload: Any) -> list[dict[str, Any]]:
    if not isinstance(payload, dict):
        return []
    rows = payload.get("data")
    if not isinstance(rows, list):
        return []
    parsed = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        date = row.get("date")
        if not isinstance(date, str):
            continue
        spent = _number(row.get("usage")) or 0.0
        prompt = int(_number(row.get("prompt_tokens")) or 0)
        completion = int(_number(row.get("completion_tokens")) or 0)
        parsed.append({"date": date, "usage": spent, "tokens": prompt + completion})
    return parsed


def build_trend(
    activity: list[dict[str, Any]],
    key_info: Optional[dict[str, Any]],
    *,
    korean: bool,
    now: Optional[dt.datetime] = None,
) -> dict[str, Any]:
    timezone = dt.timezone.utc
    current = (now or util.now_utc()).astimezone(timezone)

    spend_by_date: dict[str, float] = {}
    tokens_by_date: dict[str, int] = {}
    for row in activity:
        spend_by_date[row["date"]] = spend_by_date.get(row["date"], 0.0) + row["usage"]
        tokens_by_date[row["date"]] = tokens_by_date.get(row["date"], 0) + row["tokens"]

    recent_log = ""
    if key_info is not None:
        prompt = key_info.get("prompt_tokens", 0)
        completion = key_info.get("completion_tokens", 0)
        if key_info.get("usage_total", 0) > 0:
            recent_log = (
                f"프롬프트: {prompt:,} · 완성: {completion:,}" if korean else f"Prompt: {prompt:,} · Comp: {completion:,}"
            )
        else:
            recent_log = "API 키 정상 연동됨" if korean else "API Key Connected"

    return trend_mod.build_trend(
        spend_by_date=spend_by_date,
        tokens_by_date=tokens_by_date,
        now=current,
        tz=timezone,
        unit="tokens",
        cost_available=True,
        recent_log=recent_log,
        today_spend_fallback=key_info.get("usage_daily") if key_info else None,
        month_spend_fallback=key_info.get("usage_monthly") if key_info else None,
        weekly_spend_fallback=key_info.get("usage_weekly") if key_info else None,
        has_activity=bool(activity),
    )


def _rows(
    balance: float,
    trend: dict[str, Any],
    key_info: Optional[dict[str, Any]],
    korean: bool,
) -> list[dict[str, Any]]:
    labels = {
        "balance": ("잔액", "Balance"),
        "today": ("오늘 사용액", "Today Spend"),
        "month": ("당월 사용액", "Month Spend"),
        "tokens": ("총 토큰", "Total Tokens"),
        "prompt": ("프롬프트", "Prompt"),
        "completion": ("완성", "Completion"),
        "requests": ("요청 수", "Requests"),
    }

    def label(key: str) -> str:
        korean_label, english_label = labels[key]
        return korean_label if korean else english_label

    month_spend = key_info.get("usage_monthly") if key_info else None
    if not month_spend:
        month_spend = trend["last_30_days_spend_usd"]

    total_tokens = key_info.get("prompt_tokens", 0) + key_info.get("completion_tokens", 0) if key_info else 0
    if total_tokens <= 0:
        total_tokens = trend["last_30_days_tokens"]

    rows = [
        {"key": "balance", "label": label("balance"), "value": util.format_money(balance)},
        {"key": "today", "label": label("today"), "value": util.format_money(trend["today_spend_usd"])},
        {"key": "month", "label": label("month"), "value": util.format_money(month_spend or 0.0)},
        {"key": "tokens", "label": label("tokens"), "value": util.format_tokens(total_tokens)},
    ]
    if key_info:
        rows.append(
            {"key": "prompt", "label": label("prompt"), "value": util.format_tokens(key_info.get("prompt_tokens", 0))}
        )
        rows.append(
            {
                "key": "completion",
                "label": label("completion"),
                "value": util.format_tokens(key_info.get("completion_tokens", 0)),
            }
        )
    return rows


def _disconnected(korean: bool, error: Optional[str], now: dt.datetime) -> dict[str, Any]:
    return {
        "id": "openrouter",
        "name": "OpenRouter",
        "category": "token_and_cost",
        "plan_name": "OpenRouter",
        "available": False,
        "connected": False,
        "status": "unknown",
        "error": error,
        "primary_percent": 0.0,
        "metrics": {},
        "rows": [],
        "billing": {"date_string": "", "days": 0},
        "trend": trend_mod.empty_trend(),
        "updated_at": now.isoformat(),
    }


def fetch_snapshot(
    *,
    korean: bool = False,
    previous: Optional[dict[str, Any]] = None,
    now: Optional[dt.datetime] = None,
) -> dict[str, Any]:
    current = now or util.now_utc()
    key = secrets.openrouter_key()

    if not key:
        return _disconnected(korean, "missing_key", current)

    with ThreadPoolExecutor(max_workers=3) as pool:
        credits_future = pool.submit(_request, CREDITS_URL, key)
        key_future = pool.submit(_request, KEY_URL, key)
        activity_future = pool.submit(_request, ACTIVITY_URL, key)
        credits_result = credits_future.result()
        key_result = key_future.result()
        activity_result = activity_future.result()

    if credits_result.status in (401, 403) or key_result.status in (401, 403):
        return _disconnected(korean, "invalid_key", current)

    balance = parse_credits(credits_result.data) or 0.0
    key_info = parse_key_info(key_result.data)
    activity = parse_activity(activity_result.data)
    trend = build_trend(activity, key_info, korean=korean, now=current)

    if credits_result.error and key_result.error:
        if previous and previous.get("connected"):
            stale = dict(previous)
            stale["status"] = "warning"
            stale["error"] = "network"
            stale["trend"] = trend
            return stale
        return _disconnected(korean, "network", current)

    return {
        "id": "openrouter",
        "name": "OpenRouter",
        "category": "token_and_cost",
        "plan_name": "OpenRouter",
        "available": True,
        "connected": True,
        "status": "warning" if balance <= 1.0 else "normal",
        "error": None,
        "primary_percent": util.clamp_percent(balance / 10.0 * 100.0),
        "metrics": {},
        "rows": _rows(balance, trend, key_info, korean),
        "billing": {"date_string": "", "days": 0},
        "trend": trend,
        "updated_at": current.isoformat(),
    }
