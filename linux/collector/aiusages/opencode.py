"""OpenCode Go quota + local session trend."""

from __future__ import annotations

import datetime as dt
import json
import logging
import sqlite3
import urllib.parse
from pathlib import Path
from typing import Any, Optional

from . import paths, trend as trend_mod, util
from .httpclient import request_json

log = logging.getLogger(__name__)

USAGE_URL = "https://opencode.ai/zen/go/v1/usage"
CREDENTIAL_KEYS = ("access", "access_token", "accessToken", "key", "apiKey", "api_key", "token")


# --------------------------------------------------------------------------- #
# Credential discovery
# --------------------------------------------------------------------------- #


def token_from_credential_dict(data: Any) -> Optional[str]:
    if not isinstance(data, dict):
        return None
    for key in CREDENTIAL_KEYS:
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    nested = data.get("tokens")
    if isinstance(nested, dict):
        return token_from_credential_dict(nested)
    return None


def token_from_credential_json(raw: Any) -> Optional[str]:
    if not isinstance(raw, str) or not raw.strip():
        return None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return None
    return token_from_credential_dict(data)


def _connect_readonly(path: Path) -> Optional[sqlite3.Connection]:
    if not path.exists():
        return None
    uri = "file:" + urllib.parse.quote(str(path)) + "?mode=ro"
    try:
        connection = sqlite3.connect(uri, uri=True, timeout=2.0)
        connection.execute("PRAGMA busy_timeout=1000")
        return connection
    except sqlite3.Error as exc:
        log.debug("sqlite open failed for %s: %s", path, exc)
        return None


def _table_columns(connection: sqlite3.Connection, table: str) -> list[str]:
    try:
        return [row[1] for row in connection.execute(f"PRAGMA table_info({table})")]
    except sqlite3.Error:
        return []


def read_token_from_db(path: Optional[Path] = None) -> Optional[str]:
    db_path = path or paths.opencode_db()
    connection = _connect_readonly(db_path)
    if connection is None:
        return None

    try:
        columns = _table_columns(connection, "credential")
        if not columns:
            return None

        filters = []
        if "integration_id" in columns:
            filters.append("integration_id IN ('opencode-go', 'opencode')")
        if "connector_id" in columns:
            filters.append("connector_id IN ('opencode-go', 'opencode')")
        if "label" in columns:
            filters.append("label IN ('OpenCode Go', 'OpenCode', 'Default')")
        if not filters:
            return None

        order = []
        if "active" in columns:
            order.append("active DESC")
        if "time_updated" in columns:
            order.append("time_updated DESC")

        query = f"SELECT value FROM credential WHERE {' OR '.join(filters)}"
        if order:
            query += " ORDER BY " + ", ".join(order)
        query += " LIMIT 20;"

        for (value,) in connection.execute(query):
            token = token_from_credential_json(value)
            if token:
                return token
    except sqlite3.Error as exc:
        log.debug("credential query failed: %s", exc)
    finally:
        connection.close()
    return None


def read_token_from_auth_files() -> Optional[str]:
    for path in paths.opencode_auth_files():
        try:
            with path.open("r", encoding="utf-8") as handle:
                payload = json.load(handle)
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(payload, dict):
            continue
        entry = payload.get("opencode-go") or payload.get("opencode")
        token = token_from_credential_dict(entry)
        if token:
            return token
    return None


def find_token() -> Optional[str]:
    return read_token_from_db() or read_token_from_auth_files()


# --------------------------------------------------------------------------- #
# API parsing
# --------------------------------------------------------------------------- #


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


def parse_usage_payload(payload: Any) -> Optional[dict[str, Any]]:
    """Return remaining percentages + reset timestamps.

    A partial payload must be rejected: inventing percentages is worse than
    keeping the previous snapshot.
    """

    if not isinstance(payload, dict):
        return None
    usage = payload.get("usage")
    if not isinstance(usage, dict):
        return None

    windows: dict[str, Any] = {}
    for key, api_key in (("five_hour", "rolling"), ("weekly", "weekly"), ("monthly", "monthly")):
        window = usage.get(api_key)
        if not isinstance(window, dict):
            return None
        used = _number(window.get("percent"))
        if used is None:
            return None
        windows[key] = {
            "remaining_percent": util.clamp_percent(100.0 - used),
            "reset": window.get("resetsAt"),
        }
    return windows


# --------------------------------------------------------------------------- #
# Local trend
# --------------------------------------------------------------------------- #


def local_trend(korean: bool = False, now: Optional[dt.datetime] = None) -> dict[str, Any]:
    """Aggregate ``session_message`` rows over the last 35 days.

    OpenCode's own ``stats`` command counts input + output + reasoning + cache
    read/write.  Summing only input+output under-reported real traffic by an
    order of magnitude, so all five counters are included here too.
    """

    path = paths.opencode_db()
    connection = _connect_readonly(path)
    if connection is None:
        return trend_mod.empty_trend()

    query = """
    SELECT
        date(time_created / 1000, 'unixepoch', 'localtime') AS day,
        coalesce(sum(json_extract(data, '$.cost')), 0.0) AS spend,
        coalesce(sum(
            coalesce(json_extract(data, '$.tokens.input'), 0) +
            coalesce(json_extract(data, '$.tokens.output'), 0) +
            coalesce(json_extract(data, '$.tokens.reasoning'), 0) +
            coalesce(json_extract(data, '$.tokens.cache.read'), 0) +
            coalesce(json_extract(data, '$.tokens.cache.write'), 0)
        ), 0) AS tokens
    FROM session_message
    WHERE type = 'assistant' AND time_created >= ?
    GROUP BY day
    ORDER BY day DESC
    LIMIT 35;
    """

    current = now or dt.datetime.now().astimezone()
    cutoff_ms = int((current.timestamp() - 35 * 86400) * 1000)

    spend_by_date: dict[str, float] = {}
    tokens_by_date: dict[str, int] = {}
    recent_log = ""

    try:
        for day, spend, tokens in connection.execute(query, (cutoff_ms,)):
            spend_by_date[str(day)] = float(spend or 0.0)
            tokens_by_date[str(day)] = int(tokens or 0)

        row = connection.execute(
            "SELECT coalesce(json_extract(data, '$.model.id'), 'opencode-go') FROM session_message "
            "WHERE type = 'assistant' ORDER BY time_created DESC LIMIT 1"
        ).fetchone()
        if row and row[0]:
            recent_log = (
                f"최근 모델: {row[0]}" if korean else f"Recent model: {row[0]}"
            )
    except sqlite3.Error as exc:
        log.debug("opencode trend query failed: %s", exc)
        return trend_mod.empty_trend()
    finally:
        connection.close()

    return trend_mod.build_trend(
        spend_by_date=spend_by_date,
        tokens_by_date=tokens_by_date,
        now=current,
        tz=current.tzinfo,
        unit="tokens",
        cost_available=True,
        recent_log=recent_log,
    )


# --------------------------------------------------------------------------- #
# Snapshot
# --------------------------------------------------------------------------- #


def _unavailable(korean: bool, error: Optional[str], now: Optional[dt.datetime], trend: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": "opencode",
        "name": "OpenCode Go",
        "category": "quota",
        "plan_name": "OpenCode Go",
        "available": False,
        "status": "unknown",
        "error": error,
        "primary_percent": 0.0,
        "metrics": {},
        "rows": [],
        "billing": {"date_string": "", "days": 0},
        "trend": trend,
        "updated_at": (now or util.now_utc()).isoformat(),
    }


def _rows(windows: dict[str, Any], korean: bool, now: dt.datetime) -> list[dict[str, Any]]:
    labels = {
        "five_hour": ("5시간 윈도우", "5-hour window"),
        "weekly": ("주간", "Weekly"),
        "monthly": ("월간", "Monthly"),
    }
    keys = {
        "five_hour": "opencode_5h",
        "weekly": "opencode_weekly",
        "monthly": "opencode_monthly",
    }
    rows = []
    for window_id in ("five_hour", "weekly", "monthly"):
        window = windows.get(window_id)
        if not window:
            continue
        korean_label, english_label = labels[window_id]
        percent = util.clamp_percent(window.get("remaining_percent"))
        rows.append(
            {
                "key": keys[window_id],
                "label": korean_label if korean else english_label,
                "percent": percent,
                "reset": util.format_countdown(window.get("reset"), korean, now),
                "reset_iso": window.get("reset"),
            }
        )
    return rows


def snapshot_from_payload(
    payload: Any,
    *,
    korean: bool,
    now: Optional[dt.datetime] = None,
    trend: Optional[dict[str, Any]] = None,
) -> Optional[dict[str, Any]]:
    windows = parse_usage_payload(payload)
    if windows is None:
        return None

    current = now or util.now_utc()
    rows = _rows(windows, korean, current)
    metrics = {row["key"]: row["percent"] for row in rows}

    monthly_reset = windows["monthly"].get("reset")
    monthly_percent = metrics.get("opencode_monthly", 0.0)
    billing_string = util.format_countdown(monthly_reset, korean, current)
    reset_at = util.parse_iso8601(monthly_reset)
    days_until = 0
    if reset_at is not None:
        days_until = max(0, int((reset_at - current).total_seconds()) // 86400)

    return {
        "id": "opencode",
        "name": "OpenCode Go",
        "category": "quota",
        "plan_name": "OpenCode Go",
        "available": True,
        "status": util.status_for_percent(monthly_percent),
        "error": None,
        "primary_percent": monthly_percent,
        "metrics": metrics,
        "rows": rows,
        "billing": {"date_string": billing_string, "days": days_until},
        "trend": trend if trend is not None else trend_mod.empty_trend(),
        "updated_at": current.isoformat(),
    }


def fetch_snapshot(
    *,
    korean: bool = False,
    previous: Optional[dict[str, Any]] = None,
    now: Optional[dt.datetime] = None,
) -> dict[str, Any]:
    current = now or util.now_utc()
    local = local_trend(korean, current)
    token = find_token()

    if not token:
        return _unavailable(korean, "no_credentials", current, local)

    result = request_json(
        USAGE_URL,
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
        timeout=6.0,
    )

    if result.status == 429:
        if previous and previous.get("available"):
            stale = dict(previous)
            stale["status"] = "rate_limited"
            stale["trend"] = local
            return stale
        snapshot = _unavailable(korean, "rate_limited", current, local)
        snapshot["status"] = "rate_limited"
        return snapshot

    snapshot = None
    if result.ok:
        snapshot = snapshot_from_payload(result.data, korean=korean, now=current, trend=local)

    if snapshot is not None:
        return snapshot

    if previous and previous.get("available"):
        stale = dict(previous)
        stale["status"] = "warning"
        stale["trend"] = local
        stale["error"] = "malformed" if result.ok else "network"
        return stale

    error = "unauthorized" if result.status in (401, 403) else ("rate_limited" if result.status == 429 else "network")
    return _unavailable(korean, error, current, local)
