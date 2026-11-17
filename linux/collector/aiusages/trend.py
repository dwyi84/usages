"""30-day trend aggregation shared by every provider.

The macOS app builds the chart from three different sources (OpenCode sessions,
Antigravity conversation summaries and OpenRouter activity).  All three end up in
the same shape: 30 daily buckets, normalised bar heights and a hover payload.
"""

from __future__ import annotations

import datetime as dt
from typing import Any, Optional

WINDOW_DAYS = 30


def empty_trend(*, unit: str = "tokens", cost_available: bool = True) -> dict[str, Any]:
    return {
        "today_spend_usd": 0.0,
        "today_tokens": 0,
        "yesterday_spend_usd": 0.0,
        "yesterday_tokens": 0,
        "last_30_days_spend_usd": 0.0,
        "last_30_days_tokens": 0,
        "daily_bars": [0.0] * WINDOW_DAYS,
        "daily_points": [],
        "daily_avg_spend_usd": 0.0,
        "daily_avg_tokens": 0,
        "peak_label": "",
        "peak_tokens": 0,
        "recent_log": "",
        "unit": unit,
        "cost_available": cost_available,
    }


def build_trend(
    *,
    spend_by_date: dict[str, float],
    tokens_by_date: dict[str, int],
    now: Optional[dt.datetime] = None,
    tz: Optional[dt.tzinfo] = None,
    unit: str = "tokens",
    cost_available: bool = True,
    recent_log: str = "",
    today_spend_fallback: Optional[float] = None,
    month_spend_fallback: Optional[float] = None,
    weekly_spend_fallback: Optional[float] = None,
    has_activity: bool = True,
) -> dict[str, Any]:
    """Mirror of ``OpenRouterProvider.buildTrendSummary`` / local trend builders."""

    timezone = tz or (dt.datetime.now().astimezone().tzinfo or dt.timezone.utc)
    current = (now or dt.datetime.now(timezone)).astimezone(timezone)
    today = current.date()

    today_key = today.isoformat()
    yesterday_key = (today - dt.timedelta(days=1)).isoformat()

    def key(day: dt.date) -> str:
        return day.isoformat()

    today_spend = spend_by_date.get(today_key, today_spend_fallback if today_spend_fallback is not None else 0.0)
    today_tokens = int(tokens_by_date.get(today_key, 0))
    yesterday_spend = float(spend_by_date.get(yesterday_key, 0.0))
    yesterday_tokens = int(tokens_by_date.get(yesterday_key, 0))

    daily_counts: list[int] = []
    daily_points: list[dict[str, Any]] = []
    last_30_spend = 0.0
    last_30_tokens = 0

    for offset in range(WINDOW_DAYS - 1, -1, -1):
        day = today - dt.timedelta(days=offset)
        day_key = key(day)
        spend = float(spend_by_date.get(day_key, 0.0))
        tokens = int(tokens_by_date.get(day_key, 0))
        last_30_spend += spend
        last_30_tokens += tokens
        daily_counts.append(tokens)
        daily_points.append(
            {
                "date": day_key,
                "label": day.strftime("%m/%d"),
                "spend_usd": spend,
                "tokens": tokens,
                "normalized": 0.0,
            }
        )

    # Without a management key OpenRouter's activity endpoint is unavailable.
    # Fall back to the /key counters, but never substitute lifetime totals.
    if not has_activity:
        fallback = month_spend_fallback or 0.0
        if fallback <= 0:
            fallback = weekly_spend_fallback or 0.0
        if fallback <= 0:
            fallback = today_spend
        last_30_spend = fallback
        last_30_tokens = today_tokens
        if daily_points:
            daily_points[-1]["spend_usd"] = today_spend
            daily_points[-1]["tokens"] = today_tokens

    max_tokens = max(max(daily_counts) if daily_counts else 0, 1)
    daily_bars = [0.0 if count == 0 else count / max_tokens for count in daily_counts]

    for point in daily_points:
        point["normalized"] = point["tokens"] / max_tokens if point["tokens"] > 0 else 0.0

    peak_label = ""
    peak_tokens = 0
    if daily_points:
        peak = max(daily_points, key=lambda value: value["tokens"])
        if peak["tokens"] > 0:
            peak_label = peak["label"]
            peak_tokens = int(peak["tokens"])

    return {
        "today_spend_usd": float(today_spend),
        "today_tokens": today_tokens,
        "yesterday_spend_usd": yesterday_spend,
        "yesterday_tokens": yesterday_tokens,
        "last_30_days_spend_usd": float(last_30_spend),
        "last_30_days_tokens": int(last_30_tokens),
        "daily_bars": daily_bars,
        "daily_points": daily_points,
        "daily_avg_spend_usd": float(last_30_spend) / WINDOW_DAYS,
        "daily_avg_tokens": int(last_30_tokens / WINDOW_DAYS),
        "peak_label": peak_label,
        "peak_tokens": peak_tokens,
        "recent_log": recent_log,
        "unit": unit,
        "cost_available": cost_available,
    }
