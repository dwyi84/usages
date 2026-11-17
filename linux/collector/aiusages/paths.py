"""Filesystem locations used by the collector."""

from __future__ import annotations

import os
from pathlib import Path


def home() -> Path:
    override = os.environ.get("AIUSAGES_HOME")
    if override:
        return Path(override).expanduser()
    return Path.home()


def cache_dir() -> Path:
    override = os.environ.get("AIUSAGES_CACHE_DIR")
    if override:
        return Path(override).expanduser()
    base = os.environ.get("XDG_CACHE_HOME")
    root = Path(base).expanduser() if base else home() / ".cache"
    return root / "aiusages"


def state_file() -> Path:
    return cache_dir() / "state.json"


def opencode_db() -> Path:
    override = os.environ.get("AIUSAGES_OPENCODE_DB")
    if override:
        return Path(override).expanduser()
    return home() / ".local" / "share" / "opencode" / "opencode.db"


def opencode_auth_files() -> list[Path]:
    return [
        home() / ".local" / "share" / "opencode" / "auth.json",
        home() / ".config" / "opencode" / "auth.json",
    ]


def gemini_trend_db() -> Path:
    override = os.environ.get("AIUSAGES_GEMINI_DB")
    if override:
        return Path(override).expanduser()
    return home() / ".gemini" / "antigravity-cli" / "conversation_summaries.db"


def agy_candidates() -> list[Path]:
    override = os.environ.get("AIUSAGES_AGY")
    if override:
        return [Path(override).expanduser()]
    return [
        home() / ".local" / "bin" / "agy",
        Path("/usr/local/bin/agy"),
        Path("/usr/bin/agy"),
    ]


def ensure_cache_dir() -> Path:
    directory = cache_dir()
    directory.mkdir(parents=True, exist_ok=True)
    try:
        directory.chmod(0o700)
    except OSError:
        pass
    return directory
