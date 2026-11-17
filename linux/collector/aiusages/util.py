"""Shared helpers: timestamps, countdown labels, gauge status."""

from __future__ import annotations

import datetime as dt
import os
import re
from typing import Any, Optional

UTC = dt.timezone.utc

_FRACTIONAL = re.compile(r"(\.\d{6})\d+")


def parse_iso8601(value: Optional[str]) -> Optional[dt.datetime]:
    """Parse the ISO-8601 variants the providers actually return.

    Providers are inconsistent about fractional seconds and offsets:

    * OpenCode Go: ``2026-11-03T17:57:37.000Z``
    * Google Cloud Code: ``2026-11-07T04:57:11Z``
    * Antigravity CLI: ``2026-11-23T06:25:09Z``
    """

    if value is None:
        return None
    raw = str(value).strip()
    if not raw:
        return None

    # Python < 3.11 rejects more than 6 fractional digits.
    raw = _FRACTIONAL.sub(r"\1", raw)

    if raw.endswith("Z"):
        raw = raw[:-1] + "+00:00"

    # "+0900" -> "+09:00"
    raw = re.sub(r"([+-]\d{2})(\d{2})$", r"\1:\2", raw)

    try:
        parsed = dt.datetime.fromisoformat(raw)
    except ValueError:
        return None

    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed


def now_utc() -> dt.datetime:
    return dt.datetime.now(UTC)


def format_countdown(reset_iso: Optional[str], korean: bool, now: Optional[dt.datetime] = None) -> str:
    """Port of the macOS ``formatCountdown`` helper."""

    when = parse_iso8601(reset_iso)
    if when is None:
        return "쿼터 여유" if korean else "Quota available"

    current = now or now_utc()
    diff = max(0, int((when - current).total_seconds()))
    total_hours = diff // 3600
    mins = (diff % 3600) // 60

    if total_hours >= 24:
        days, hours = divmod(total_hours, 24)
        if korean:
            return f"{days}일 {hours}시간 후 리셋"
        return f"Resets in {days}d {hours}h"

    if korean:
        return f"{total_hours}시간 {mins}분 후 리셋"
    return f"Resets in {total_hours}h {mins}m"


def calculate_next_billing(
    day_of_month: int,
    now: Optional[dt.datetime] = None,
    korean: bool = False,
) -> dict[str, Any]:
    """Port of ``GoogleAIProvider.calculateNextBilling``.

    Google does not expose a renewal date, so the user configures the day of
    month.  Day 31 must clamp to the last day of shorter months.
    """

    if day_of_month < 1 or day_of_month > 31:
        return {"date_string": "", "days": 0}

    current = now or dt.datetime.now().astimezone()
    local = current.astimezone()

    target_year = local.year
    target_month = local.month
    if day_of_month < local.day:
        target_month += 1
        if target_month > 12:
            target_month = 1
            target_year += 1

    # Clamp to the length of the target month.
    probe = dt.date(target_year, target_month, 1)
    if target_month == 12:
        next_month = dt.date(target_year + 1, 1, 1)
    else:
        next_month = dt.date(target_year, target_month + 1, 1)
    month_length = (next_month - probe).days
    clamped_day = min(day_of_month, month_length)

    target = dt.datetime(
        target_year,
        target_month,
        clamped_day,
        tzinfo=local.tzinfo,
    )

    diff = max(0, int((target - local).total_seconds()))
    total_hours = diff // 3600
    days = total_hours // 24
    hours = total_hours % 24

    if days == 0:
        if hours == 0:
            date_string = f"오늘 리셋 (매월 {day_of_month}일)" if korean else f"Resets today ({day_of_month}th)"
        else:
            date_string = (
                f"{hours}시간 후 리셋 (매월 {day_of_month}일)" if korean else f"Resets in {hours}h ({day_of_month}th)"
            )
    else:
        date_string = (
            f"{days}일 {hours}시간 후 리셋 (매월 {day_of_month}일)"
            if korean
            else f"Resets in {days}d {hours}h ({day_of_month}th)"
        )

    return {"date_string": date_string, "days": days}


def clamp_percent(value: Any, default: float = 0.0) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return default
    if number != number:  # NaN
        return default
    return max(0.0, min(100.0, number))


def fraction_to_percent(fraction: Any) -> Optional[float]:
    try:
        number = float(fraction)
    except (TypeError, ValueError):
        return None
    return clamp_percent(number * 100.0)


def status_for_percent(percent: float) -> str:
    if percent <= 15.0:
        return "critical"
    if percent <= 35.0:
        return "warning"
    return "normal"


def local_timezone():
    return dt.datetime.now().astimezone().tzinfo or UTC


def detect_korean() -> bool:
    """Best-effort mirror of ``L10n.isKorean`` for CLI use."""

    forced = os.environ.get("AIUSAGES_LANG", "").strip().lower()
    if forced:
        return forced.startswith("ko")

    for key in ("LC_ALL", "LC_MESSAGES", "LANGUAGE", "LANG"):
        value = os.environ.get(key, "")
        if value:
            return value.lower().startswith("ko")
    return False


def format_money(value: float) -> str:
    return f"${value:,.2f}"


def format_tokens(value: int) -> str:
    return f"{int(value):,}"
