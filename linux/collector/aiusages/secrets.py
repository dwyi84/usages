"""Secret storage backed by the freedesktop Secret Service (GNOME Keyring).

The macOS app used the login Keychain with service
``com.melissasoft.aiusages`` / account ``openrouter_api_key``.  On Linux we use
the same service/account pair through libsecret, which keeps migrated keys
recognisable and avoids plain-text credentials.

Antigravity (``agy``) stores its Google OAuth token as service ``gemini`` /
username ``antigravity``.  The payload is the same JSON blob the macOS app read
from the Keychain, optionally prefixed with ``go-keyring-base64:``.
"""

from __future__ import annotations

import json
import logging
import os
from typing import Any, Optional

log = logging.getLogger(__name__)

APP_SERVICE = "com.melissasoft.aiusages"
OPENROUTER_ACCOUNT = "openrouter_api_key"
GOOGLE_SERVICE = "gemini"
GOOGLE_ACCOUNT = "antigravity"

_SECRET_SCHEMA_NAME = "org.freedesktop.Secret.Generic"
_schema = None
_secret_module = None


def _load_secret() -> Optional[Any]:
    global _secret_module, _schema
    if _secret_module is not None:
        return _secret_module
    if os.environ.get("AIUSAGES_DISABLE_KEYRING"):
        return None
    try:
        import gi

        gi.require_version("Secret", "1")
        from gi.repository import Secret  # noqa: WPS433 (runtime import)

        _secret_module = Secret
        _schema = Secret.Schema.new(
            _SECRET_SCHEMA_NAME,
            Secret.SchemaFlags.NONE,
            {
                "service": Secret.SchemaAttributeType.STRING,
                "username": Secret.SchemaAttributeType.STRING,
            },
        )
        return _secret_module
    except Exception as exc:  # pragma: no cover - depends on host
        log.debug("libsecret unavailable: %s", exc)
        return None


def lookup(service: str, username: str) -> Optional[str]:
    secret = _load_secret()
    if secret is None or _schema is None:
        return None
    try:
        value = secret.password_lookup_sync(
            _schema,
            {"service": service, "username": username},
            None,
        )
    except Exception as exc:  # pragma: no cover - depends on host
        log.debug("secret lookup failed for %s/%s: %s", service, username, exc)
        return None
    return value or None


def store(service: str, username: str, value: str) -> bool:
    secret = _load_secret()
    if secret is None or _schema is None:
        return False
    try:
        return bool(
            secret.password_store_sync(
                _schema,
                {"service": service, "username": username},
                secret.COLLECTION_DEFAULT,
                f"AI Usages ({service})",
                value,
                None,
            )
        )
    except Exception as exc:  # pragma: no cover - depends on host
        log.debug("secret store failed for %s/%s: %s", service, username, exc)
        return False


def clear(service: str, username: str) -> None:
    secret = _load_secret()
    if secret is None or _schema is None:
        return
    try:
        secret.password_clear_sync(_schema, {"service": service, "username": username}, None)
    except Exception as exc:  # pragma: no cover - depends on host
        log.debug("secret clear failed for %s/%s: %s", service, username, exc)


def openrouter_key() -> Optional[str]:
    for candidate in (
        lookup(APP_SERVICE, OPENROUTER_ACCOUNT),
        os.environ.get("OPENROUTER_API_KEY"),
    ):
        if candidate and candidate.strip():
            return candidate.strip()
    return None


def google_credentials() -> Optional[dict[str, Any]]:
    """Return ``{access_token, refresh_token, expiry}`` from the keyring."""

    raw = lookup(GOOGLE_SERVICE, GOOGLE_ACCOUNT)
    if not raw:
        return None

    text = raw.strip()
    prefix = "go-keyring-base64:"
    if text.startswith(prefix):
        import base64

        try:
            text = base64.b64decode(text[len(prefix) :]).decode("utf-8", "replace")
        except Exception:
            return None

    try:
        payload = json.loads(text)
    except json.JSONDecodeError:
        return None

    token = payload.get("token") if isinstance(payload, dict) else None
    if not isinstance(token, dict):
        return None
    if not token.get("access_token") and not token.get("refresh_token"):
        return None
    return token
