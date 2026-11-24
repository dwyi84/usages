"""Google AI Pro (Antigravity / Cloud Code) quotas.

Two data paths are used on Linux, mirroring the macOS app:

1. The Cloud Code REST endpoint with an OAuth access token.  The token comes
   from the Secret Service entry written by ``agy`` (service ``gemini``,
   username ``antigravity``).  Expired tokens are refreshed directly so the
   fast (~0.2s) path keeps working.
2. The ``agy`` CLI as a fallback and to fill in the ``Gemini 4 Argon`` group,
   which the REST response never includes.  This call costs ~6s / 230MB, so it
   runs at most once every ``agy_max_age`` seconds.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import logging
import os
import platform
import re
import shutil
import sqlite3
import subprocess
import urllib.parse
from pathlib import Path
from typing import Any, Optional

from . import paths, secrets, trend as trend_mod, util
from .httpclient import request_json

log = logging.getLogger(__name__)

_CLIENT_ID_RE = re.compile(rb"[0-9]{12,13}-[a-z0-9]{32}\.apps\.googleusercontent\.com")
_CLIENT_SECRET_RE = re.compile(rb"GOCSPX-[A-Za-z0-9_-]{28}")
_CACHED_OAUTH_CLIENT: Optional[tuple[str, str]] = None
TOKEN_URL = "https://oauth2.googleapis.com/token"
REST_ENDPOINTS = (
    "https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
    "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
)
PROJECTS = ("aicode-consumers", "default-cli-project", "")

ROW_ORDER = (
    ("gemini_5h", "Gemini 5시간", "Gemini 5h"),
    ("gemini_weekly", "Gemini 주간", "Gemini Weekly"),
    ("claude_5h", "Claude & GPT 5시간", "Claude & GPT 5h"),
    ("claude_weekly", "Claude & GPT 주간", "Claude & GPT Weekly"),
    ("argon_weekly", "Gemini 4 Argon 주간", "Gemini 4 Argon Weekly"),
)

# Group ordering used when collapsing the groups into a single panel value.
WEEKLY_KEYS = ("gemini_weekly", "claude_weekly", "argon_weekly")
FIVE_HOUR_KEYS = ("gemini_5h", "claude_5h")


def _arch() -> str:
    machine = platform.machine().lower()
    return "arm64" if machine in ("aarch64", "arm64") else "amd64"


def user_agent() -> str:
    return f"antigravity/2.24.0 (aidev_client; os_type=linux; arch={_arch()})"


# --------------------------------------------------------------------------- #
# Quota parsing
# --------------------------------------------------------------------------- #


def _empty_limits() -> dict[str, Any]:
    return {}


def _store(limits: dict[str, Any], key: str, fraction: Any, reset_iso: Any) -> None:
    percent = util.fraction_to_percent(fraction)
    if percent is None:
        return
    limits[key] = {"percent": percent, "reset_iso": reset_iso}


def parse_rest_quota(payload: Any) -> Optional[dict[str, Any]]:
    """Parse ``retrieveUserQuotaSummary`` (camelCase fields)."""

    if not isinstance(payload, dict):
        return None
    groups = payload.get("groups")
    if not isinstance(groups, list) or not groups:
        return None

    limits: dict[str, Any] = {}
    for group in groups:
        if not isinstance(group, dict):
            continue
        group_name = str(group.get("displayName") or "").lower()
        buckets = group.get("buckets") or []
        if not isinstance(buckets, list):
            continue
        for bucket in buckets:
            if not isinstance(bucket, dict):
                continue
            bucket_id = str(bucket.get("bucketId") or "").lower()
            fraction = bucket.get("remainingFraction")
            reset = bucket.get("resetTime")

            if group_name == "gemini models" or ("gemini" in group_name and "argon" not in group_name):
                if "weekly" in bucket_id:
                    _store(limits, "gemini_weekly", fraction, reset)
                elif "5h" in bucket_id or "five" in bucket_id:
                    _store(limits, "gemini_5h", fraction, reset)
            elif "claude" in group_name or "3p" in group_name:
                if "weekly" in bucket_id:
                    _store(limits, "claude_weekly", fraction, reset)
                elif "5h" in bucket_id or "five" in bucket_id:
                    _store(limits, "claude_5h", fraction, reset)
            elif "argon" in group_name or "argon" in bucket_id:
                _store(limits, "argon_weekly", fraction, reset)

    return limits or None


def parse_agy_usage(payload: Any) -> Optional[dict[str, Any]]:
    """Parse ``agy --output-format json --print /usage`` (snake_case fields)."""

    if not isinstance(payload, dict):
        return None
    command = payload.get("command")
    if not isinstance(command, dict):
        return None
    data = command.get("data")
    if not isinstance(data, dict):
        return None
    groups = data.get("groups")
    if not isinstance(groups, list):
        return None

    limits: dict[str, Any] = {}
    for group in groups:
        if not isinstance(group, dict):
            continue
        group_name = str(group.get("name") or "").lower()
        buckets = group.get("buckets") or []
        if not isinstance(buckets, list):
            continue
        for bucket in buckets:
            if not isinstance(bucket, dict):
                continue
            bucket_id = str(bucket.get("id") or "").lower()
            fraction = bucket.get("remaining_fraction")
            reset = bucket.get("reset_time")

            if group_name == "gemini models" or ("gemini" in group_name and "argon" not in group_name):
                if "weekly" in bucket_id:
                    _store(limits, "gemini_weekly", fraction, reset)
                elif "5h" in bucket_id or "five" in bucket_id:
                    _store(limits, "gemini_5h", fraction, reset)
            elif "claude" in group_name or "3p" in group_name:
                if "weekly" in bucket_id:
                    _store(limits, "claude_weekly", fraction, reset)
                elif "5h" in bucket_id or "five" in bucket_id:
                    _store(limits, "claude_5h", fraction, reset)
            elif "argon" in group_name or "argon" in bucket_id:
                _store(limits, "argon_weekly", fraction, reset)

    return limits or None


def merge_limits(base: Optional[dict[str, Any]], overlay: Optional[dict[str, Any]]) -> dict[str, Any]:
    merged: dict[str, Any] = {}
    if isinstance(base, dict):
        for key, value in base.items():
            if isinstance(value, dict):
                merged[key] = dict(value)
    if isinstance(overlay, dict):
        for key, value in overlay.items():
            if isinstance(value, dict):
                merged[key] = dict(value)
    return merged


def overall_remaining(limits: dict[str, Any]) -> float:
    weekly = [limits[key]["percent"] for key in WEEKLY_KEYS if key in limits]
    if weekly:
        return min(weekly)
    five_hour = [limits[key]["percent"] for key in FIVE_HOUR_KEYS if key in limits]
    return min(five_hour) if five_hour else 0.0


# --------------------------------------------------------------------------- #
# OAuth
# --------------------------------------------------------------------------- #


def _token_id(refresh_token: str) -> str:
    return hashlib.sha256(refresh_token.encode("utf-8")).hexdigest()[:16]


def _oauth_client_candidates(
    credentials: dict[str, Any],
    token_cache: Optional[dict[str, Any]] = None,
) -> list[tuple[str, str]]:
    candidates: list[tuple[str, str]] = []

    def add(cid: Any, csec: Any) -> None:
        if isinstance(cid, str) and isinstance(csec, str) and cid and csec:
            pair = (cid.strip(), csec.strip())
            if pair[0] and pair[1] and pair not in candidates:
                candidates.append(pair)

    add(credentials.get("client_id"), credentials.get("client_secret"))
    add(os.environ.get("AIUSAGES_GOOGLE_CLIENT_ID"), os.environ.get("AIUSAGES_GOOGLE_CLIENT_SECRET"))

    if _CACHED_OAUTH_CLIENT is not None:
        add(_CACHED_OAUTH_CLIENT[0], _CACHED_OAUTH_CLIENT[1])

    if isinstance(token_cache, dict):
        add(token_cache.get("client_id"), token_cache.get("client_secret"))

    binary = find_agy()
    if binary:
        try:
            data = Path(binary).resolve().read_bytes()
            ids = [m.decode("ascii") for m in _CLIENT_ID_RE.findall(data)]
            secs = [m.decode("ascii") for m in _CLIENT_SECRET_RE.findall(data)]
            agy_pairs = list(zip(ids, secs))
            agy_pairs.sort(key=lambda pair: 0 if pair[0].startswith("1071") else 1)
            for cid, csec in agy_pairs:
                add(cid, csec)
        except OSError as exc:
            log.debug("failed reading agy binary for OAuth client: %s", exc)

    return candidates or [("", "")]


def refresh_access_token(
    credentials: dict[str, Any],
    token_cache: Optional[dict[str, Any]],
    *,
    now: Optional[dt.datetime] = None,
    force: bool = False,
) -> Optional[str]:
    global _CACHED_OAUTH_CLIENT

    current = now or util.now_utc()
    refresh_token = credentials.get("refresh_token")
    if not isinstance(refresh_token, str) or not refresh_token:
        # Some accounts only expose a short-lived access token.
        access = credentials.get("access_token")
        return access if isinstance(access, str) and access else None

    cache = token_cache or {}
    cached_access = cache.get("access_token")
    expires_at = cache.get("expires_at")
    same_token = cache.get("refresh_id") == _token_id(refresh_token)

    if not force and same_token and isinstance(cached_access, str) and cached_access:
        try:
            if float(expires_at or 0) > current.timestamp() + 60:
                return cached_access
        except (TypeError, ValueError):
            pass

    access: Optional[str] = None
    data: Optional[dict[str, Any]] = None
    used_client: Optional[tuple[str, str]] = None
    last_error: Any = None

    for client_id, client_secret in _oauth_client_candidates(credentials, token_cache):
        result = request_json(
            TOKEN_URL,
            method="POST",
            payload={
                "client_id": client_id,
                "client_secret": client_secret,
                "refresh_token": refresh_token,
                "grant_type": "refresh_token",
            },
            headers={"Content-Type": "application/json"},
            timeout=10.0,
        )
        candidate_data = result.data if isinstance(result.data, dict) else None
        candidate_access = candidate_data.get("access_token") if candidate_data else None
        if isinstance(candidate_access, str) and candidate_access:
            access = candidate_access
            data = candidate_data
            if client_id and client_secret:
                used_client = (client_id, client_secret)
            break
        last_error = result.error or result.status

    if not isinstance(access, str) or not access:
        log.debug("token refresh failed: %s", last_error)
        return None

    try:
        expires_in = float((data or {}).get("expires_in") or 3600)
    except (TypeError, ValueError):
        expires_in = 3600.0
    if used_client is not None:
        _CACHED_OAUTH_CLIENT = used_client
    if token_cache is not None:
        token_cache.update(
            {
                "access_token": access,
                "expires_at": current.timestamp() + expires_in,
                "refresh_id": _token_id(refresh_token),
                "updated_at": current.timestamp(),
            }
        )
        if used_client is not None:
            token_cache["client_id"] = used_client[0]
            token_cache["client_secret"] = used_client[1]
    return access


# --------------------------------------------------------------------------- #
# REST + agy transports
# --------------------------------------------------------------------------- #


def fetch_rest_quota(access_token: str, *, now: Optional[dt.datetime] = None) -> tuple[Optional[dict[str, Any]], int]:
    """Try the Cloud Code endpoints.  Returns ``(limits, last_status)``."""

    last_status = 0
    for url in REST_ENDPOINTS:
        for project in PROJECTS:
            payload = {"project": project} if project else {}
            result = request_json(
                url,
                method="POST",
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "User-Agent": user_agent(),
                },
                payload=payload,
                timeout=6.0,
            )
            last_status = result.status
            if result.status == 429:
                return None, 429
            if result.ok:
                parsed = parse_rest_quota(result.data)
                if parsed:
                    return parsed, result.status
    return None, last_status


def find_agy() -> Optional[str]:
    for candidate in paths.agy_candidates():
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    found = shutil.which("agy")
    return found


def fetch_agy_limits(
    executable: Optional[str] = None,
    *,
    timeout: float = 45.0,
) -> Optional[dict[str, Any]]:
    binary = executable or find_agy()
    if not binary:
        return None

    environment = dict(os.environ)
    environment.setdefault("HOME", str(paths.home()))
    environment["PATH"] = os.pathsep.join(
        [
            str(paths.home() / ".local" / "bin"),
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
        ]
    )

    try:
        completed = subprocess.run(
            [binary, "--output-format", "json", "--print", "/usage"],
            capture_output=True,
            timeout=timeout,
            env=environment,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        log.debug("agy failed: %s", exc)
        return None

    output = (completed.stdout or b"").decode("utf-8", "replace")
    start = output.find("{")
    end = output.rfind("}")
    if start < 0 or end <= start:
        log.debug("agy returned no JSON (exit %s)", completed.returncode)
        return None
    try:
        payload = json.loads(output[start : end + 1])
    except json.JSONDecodeError:
        return None
    return parse_agy_usage(payload)


# --------------------------------------------------------------------------- #
# Local trend (Antigravity conversation summaries)
# --------------------------------------------------------------------------- #


def local_trend(korean: bool = False, now: Optional[dt.datetime] = None) -> dict[str, Any]:
    path = paths.gemini_trend_db()
    if not path.exists():
        return trend_mod.empty_trend(unit="steps", cost_available=False)

    uri = "file:" + urllib.parse.quote(str(path)) + "?mode=ro"
    try:
        connection = sqlite3.connect(uri, uri=True, timeout=2.0)
        connection.execute("PRAGMA busy_timeout=1000")
    except sqlite3.Error:
        return trend_mod.empty_trend(unit="steps", cost_available=False)

    steps_by_date: dict[str, int] = {}
    recent_log = ""
    try:
        cursor = connection.execute(
            """
            SELECT date(last_modified_time, 'localtime') AS day, sum(step_count) AS steps
            FROM conversation_summaries
            WHERE datetime(last_modified_time) >= datetime('now', '-35 days')
            GROUP BY day
            ORDER BY day ASC;
            """
        )
        for day, steps in cursor:
            steps_by_date[str(day)] = int(steps or 0)

        row = connection.execute(
            "SELECT title, step_count FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 1"
        ).fetchone()
        if row:
            title = str(row[0] or "")
            if len(title) > 20:
                title = title[:18] + "..."
            steps = int(row[1] or 0)
            recent_log = f"최근 세션: {title} ({steps} steps)" if korean else f"Recent: {title} ({steps} steps)"
    except sqlite3.Error as exc:
        log.debug("gemini trend query failed: %s", exc)
    finally:
        connection.close()

    return trend_mod.build_trend(
        spend_by_date={},
        tokens_by_date=steps_by_date,
        now=now,
        tz=(now.astimezone().tzinfo if now else None),
        unit="steps",
        cost_available=False,
        recent_log=recent_log,
    )


# --------------------------------------------------------------------------- #
# Snapshot
# --------------------------------------------------------------------------- #


def _rows(limits: dict[str, Any], korean: bool, now: dt.datetime) -> list[dict[str, Any]]:
    rows = []
    for key, korean_label, english_label in ROW_ORDER:
        entry = limits.get(key)
        if not isinstance(entry, dict):
            continue
        percent = util.clamp_percent(entry.get("percent"))
        rows.append(
            {
                "key": f"google_{key}",
                "label": korean_label if korean else english_label,
                "percent": percent,
                "reset": util.format_countdown(entry.get("reset_iso"), korean, now),
                "reset_iso": entry.get("reset_iso"),
            }
        )
    return rows


def _snapshot(
    limits: dict[str, Any],
    *,
    korean: bool,
    billing_day: int,
    status_override: Optional[str],
    error: Optional[str],
    now: dt.datetime,
) -> dict[str, Any]:
    rows = _rows(limits, korean, now)
    metrics = {row["key"]: row["percent"] for row in rows}
    overall = overall_remaining(limits)
    billing = util.calculate_next_billing(billing_day, now, korean)
    status = status_override or util.status_for_percent(overall)

    return {
        "id": "google_ai",
        "name": "Google AI Pro",
        "category": "quota",
        "plan_name": "Google AI Pro Plan",
        "available": bool(limits),
        "status": status,
        "error": error,
        "primary_percent": overall,
        "metrics": metrics,
        "rows": rows,
        "billing": billing,
        "trend": local_trend(korean, now),
        "updated_at": now.isoformat(),
    }


def _unavailable(korean: bool, error: Optional[str], now: dt.datetime, billing_day: int) -> dict[str, Any]:
    return _snapshot(
        {},
        korean=korean,
        billing_day=billing_day,
        status_override="unknown",
        error=error,
        now=now,
    )


def fetch_snapshot(
    *,
    korean: bool = False,
    billing_day: int = 0,
    previous: Optional[dict[str, Any]] = None,
    internal: Optional[dict[str, Any]] = None,
    now: Optional[dt.datetime] = None,
) -> dict[str, Any]:
    """Fetch quotas, refreshing the OAuth token and the occasional agy call."""

    current = now or util.now_utc()
    internal = internal if internal is not None else {}

    token_cache = internal.get("google_token")
    if not isinstance(token_cache, dict):
        token_cache = {}
        internal["google_token"] = token_cache

    agy_cache = internal.get("google_agy")
    if not isinstance(agy_cache, dict):
        agy_cache = {}
        internal["google_agy"] = agy_cache

    limits = _empty_limits()
    rest_limits: Optional[dict[str, Any]] = None
    rest_status = 0
    rate_limited = False

    credentials = secrets.google_credentials()
    if credentials:
        access_token = refresh_access_token(credentials, token_cache, now=current)
        if not access_token:
            # A cached token may still be valid even if a refresh was rejected.
            access_token = credentials.get("access_token")
        if access_token:
            rest_limits, rest_status = fetch_rest_quota(access_token, now=current)
            rate_limited = rest_status == 429

    # Gemini 4 Argon is now part of Gemini Models, so REST returns all quota groups.
    # Only fall back to the slow agy CLI when REST fails.
    agy_limits: Optional[dict[str, Any]] = None
    cached_agy_limits = agy_cache.get("limits")
    if isinstance(cached_agy_limits, dict):
        agy_limits = cached_agy_limits

    try:
        agy_updated_at = float(agy_cache.get("updated_at") or 0)
    except (TypeError, ValueError):
        agy_updated_at = 0.0
    agy_age = current.timestamp() - agy_updated_at

    needs_agy = not rate_limited and rest_limits is None and (not agy_limits or agy_age > 10 * 60)
    if needs_agy:
        fresh = fetch_agy_limits()
        if fresh:
            agy_limits = fresh
            agy_cache["limits"] = fresh
            agy_cache["updated_at"] = current.timestamp()

    if rate_limited:
        if previous and previous.get("available"):
            stale = dict(previous)
            stale["status"] = "rate_limited"
            stale["trend"] = local_trend(korean, current)
            return stale
        return _snapshot({}, korean=korean, billing_day=billing_day, status_override="rate_limited",
                         error="rate_limited", now=current)

    # Use REST directly when available so retired groups (e.g. standalone Argon)
    # don't linger from older caches; fall back to agy when REST is unavailable.
    limits = dict(rest_limits) if rest_limits else (dict(agy_limits) if agy_limits else {})

    if limits:
        error = None if (rest_limits or agy_limits) else "network"
        return _snapshot(
            limits,
            korean=korean,
            billing_day=billing_day,
            status_override=None,
            error=error,
            now=current,
        )

    if previous and previous.get("available"):
        stale = dict(previous)
        stale["status"] = "warning"
        stale["trend"] = local_trend(korean, current)
        stale["error"] = "network"
        return stale

    return _unavailable(korean, "no_credentials", current, billing_day)
