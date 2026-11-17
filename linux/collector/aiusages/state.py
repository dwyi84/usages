"""Persistent cache for snapshots, refreshed OAuth tokens and agy results."""

from __future__ import annotations

import json
import os
import tempfile
import time
from typing import Any, Optional

from . import paths

SCHEMA_VERSION = 1


def _default_state() -> dict[str, Any]:
    return {"schema": SCHEMA_VERSION, "generated_at": 0.0, "providers": {}, "internal": {}}


def load_state() -> dict[str, Any]:
    path = paths.state_file()
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        return _default_state()
    except (OSError, json.JSONDecodeError):
        return _default_state()

    if not isinstance(data, dict):
        return _default_state()
    data.setdefault("schema", SCHEMA_VERSION)
    data.setdefault("generated_at", 0.0)
    data.setdefault("providers", {})
    data.setdefault("internal", {})
    if not isinstance(data["providers"], dict):
        data["providers"] = {}
    if not isinstance(data["internal"], dict):
        data["internal"] = {}
    return data


def save_state(state: dict[str, Any]) -> None:
    directory = paths.ensure_cache_dir()
    state = dict(state)
    state["schema"] = SCHEMA_VERSION
    state["generated_at"] = time.time()

    fd, tmp_path = tempfile.mkstemp(dir=str(directory), prefix="state-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(state, handle, ensure_ascii=False, separators=(",", ":"))
        os.chmod(tmp_path, 0o600)
        os.replace(tmp_path, paths.state_file())
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def provider_cache(state: dict[str, Any], provider_id: str) -> Optional[dict[str, Any]]:
    cached = state.get("providers", {}).get(provider_id)
    return cached if isinstance(cached, dict) else None


def internal_cache(state: dict[str, Any], key: str) -> Optional[dict[str, Any]]:
    cached = state.get("internal", {}).get(key)
    return cached if isinstance(cached, dict) else None


def set_internal_cache(state: dict[str, Any], key: str, value: dict[str, Any]) -> None:
    state.setdefault("internal", {})[key] = value


def read_cached_providers() -> dict[str, Any]:
    """Used by the extension as an instant first paint."""

    return load_state().get("providers", {})
