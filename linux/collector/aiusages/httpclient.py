"""Minimal HTTP JSON client (stdlib only).

``urllib`` is used instead of ``requests`` so the collector has zero third-party
dependencies on a stock Ubuntu install.
"""

from __future__ import annotations

import json
import logging
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any, Optional

from . import __version__

log = logging.getLogger(__name__)

USER_AGENT = f"AIUsages/{__version__} (Linux; +https://github.com/dwyi84/usages)"


@dataclass
class HttpResult:
    status: int
    data: Optional[Any] = None
    error: Optional[str] = None
    headers: Optional[dict[str, str]] = None

    @property
    def ok(self) -> bool:
        return 200 <= self.status < 300


def request_json(
    url: str,
    *,
    method: str = "GET",
    headers: Optional[dict[str, str]] = None,
    payload: Optional[Any] = None,
    timeout: float = 6.0,
) -> HttpResult:
    body = None
    request_headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
        # urllib does not transparently decompress gzip.
        "Accept-Encoding": "identity",
    }
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        request_headers["Content-Type"] = "application/json"
    if headers:
        request_headers.update(headers)

    request = urllib.request.Request(url, data=body, headers=request_headers, method=method)

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read()
            status = int(getattr(response, "status", 200) or 200)
            response_headers = {k.lower(): v for k, v in response.headers.items()}
    except urllib.error.HTTPError as exc:
        raw = exc.read() if hasattr(exc, "read") else b""
        response_headers = {k.lower(): v for k, v in (exc.headers or {}).items()}
        return HttpResult(
            status=int(exc.code or 0),
            data=_maybe_json(raw),
            error=f"HTTP {exc.code}",
            headers=response_headers,
        )
    except Exception as exc:  # network / TLS / timeout
        log.debug("request failed %s: %s", url, exc)
        return HttpResult(status=0, data=None, error=str(exc))

    return HttpResult(status=status, data=_maybe_json(raw), error=None, headers=response_headers)


def _maybe_json(raw: bytes) -> Optional[Any]:
    if not raw:
        return None
    try:
        return json.loads(raw.decode("utf-8", "replace"))
    except json.JSONDecodeError:
        return None
