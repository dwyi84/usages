"""Command line interface used by the GNOME Shell extension."""

from __future__ import annotations

import argparse
import json
import logging
import sys
from typing import Sequence

from . import __version__, collector, util


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="aiusages-collect",
        description="Collect AI provider usage for the AI Usages GNOME extension.",
    )
    parser.add_argument("--json", action="store_true", help="emit JSON (default)")
    parser.add_argument("--pretty", action="store_true", help="pretty-print the JSON")
    parser.add_argument("--korean", action="store_true", help="Korean labels (default: auto)")
    parser.add_argument("--english", action="store_true", help="English labels")
    parser.add_argument("--billing-day", type=int, default=0, help="Google renewal day of month (1-31)")
    parser.add_argument(
        "--agy-max-age",
        type=int,
        default=30 * 60,
        help="Seconds before the Antigravity CLI is queried again",
    )
    parser.add_argument(
        "--enabled",
        default="",
        help="Comma separated provider ids (opencode,google_ai,openrouter)",
    )
    parser.add_argument("--only", default="", help="Alias for --enabled")
    parser.add_argument("--no-cache", action="store_true", help="do not write the cache file")
    parser.add_argument("--print-cache", action="store_true", help="print the cached payload and exit")
    parser.add_argument("--verbose", action="store_true", help="log to stderr")
    parser.add_argument("--version", action="store_true", help="print the version")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.WARNING,
        format="aiusages: %(levelname)s %(message)s",
        stream=sys.stderr,
    )

    if args.version:
        print(__version__)
        return 0

    if args.print_cache:
        payload = collector.cached_payload()
        _emit(payload, args.pretty)
        return 0

    if args.korean and args.english:
        parser.error("--korean and --english are mutually exclusive")
    korean = True if args.korean else (False if args.english else util.detect_korean())

    enabled = args.enabled or args.only
    enabled_list = [item for item in enabled.split(",") if item.strip()] if enabled else None

    payload = collector.collect(
        enabled=enabled_list,
        korean=korean,
        billing_day=max(0, min(31, args.billing_day)),
        agy_max_age=max(60, args.agy_max_age),
        write_cache=not args.no_cache,
    )
    _emit(payload, args.pretty)
    return 0


def _emit(payload: dict, pretty: bool) -> None:
    if pretty:
        print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=False))
    else:
        print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
