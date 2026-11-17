import json
import os
import tempfile
import unittest
from unittest import mock

from aiusages import collector, state


def _snapshot(provider_id, available=True, error=None):
    return {
        "id": provider_id,
        "name": provider_id,
        "category": "token_and_cost" if provider_id == "openrouter" else "quota",
        "plan_name": provider_id,
        "available": available,
        "status": "normal" if available else "unknown",
        "error": error,
        "primary_percent": 50.0,
        "metrics": {},
        "rows": [],
        "billing": {"date_string": "", "days": 0},
        "trend": {},
        "updated_at": "2026-11-17T00:00:00+00:00",
    }


class CollectorTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.env = mock.patch.dict(os.environ, {"AIUSAGES_CACHE_DIR": self._tmp.name})
        self.env.start()
        self.addCleanup(self.env.stop)

    def test_runs_only_enabled_providers(self):
        calls = []
        with mock.patch.object(
            collector.opencode,
            "fetch_snapshot",
            lambda **kwargs: calls.append("opencode") or _snapshot("opencode"),
        ), mock.patch.object(
            collector.google,
            "fetch_snapshot",
            lambda **kwargs: calls.append("google") or _snapshot("google_ai"),
        ), mock.patch.object(
            collector.openrouter,
            "fetch_snapshot",
            lambda **kwargs: calls.append("openrouter") or _snapshot("openrouter"),
        ):
            payload = collector.collect(enabled=["opencode", "google_ai"], korean=True)

        self.assertEqual(set(payload["providers"]), {"opencode", "google_ai"})
        self.assertEqual(calls, ["opencode", "google"])
        self.assertTrue(payload["korean"])

    def test_writes_and_reuses_cache(self):
        with mock.patch.object(
            collector.opencode, "fetch_snapshot", lambda **kwargs: _snapshot("opencode")
        ):
            first = collector.collect(enabled=["opencode"])

        self.assertTrue(first["providers"]["opencode"]["available"])
        cached = collector.cached_payload()
        self.assertTrue(cached["providers"]["opencode"]["available"])
        self.assertTrue(cached["cache_path"].endswith("state.json"))

    def test_provider_failure_is_isolated(self):
        def boom(**kwargs):
            raise RuntimeError("network down")

        with mock.patch.object(collector.opencode, "fetch_snapshot", boom):
            payload = collector.collect(enabled=["opencode"])

        snapshot = payload["providers"]["opencode"]
        self.assertFalse(snapshot["available"])
        self.assertEqual(snapshot["error"], "internal_error")

    def test_provider_failure_keeps_stale_data(self):
        with mock.patch.object(
            collector.opencode, "fetch_snapshot", lambda **kwargs: _snapshot("opencode", available=True)
        ):
            collector.collect(enabled=["opencode"])

        def boom(**kwargs):
            raise RuntimeError("network down")

        with mock.patch.object(collector.opencode, "fetch_snapshot", boom):
            payload = collector.collect(enabled=["opencode"])

        snapshot = payload["providers"]["opencode"]
        self.assertTrue(snapshot["available"])
        self.assertEqual(snapshot["status"], "warning")
        self.assertEqual(snapshot["error"], "internal_error")

    def test_partial_run_keeps_other_provider_snapshots(self):
        with mock.patch.object(
            collector.opencode, "fetch_snapshot", lambda **kwargs: _snapshot("opencode")
        ), mock.patch.object(
            collector.google, "fetch_snapshot", lambda **kwargs: _snapshot("google_ai")
        ):
            collector.collect(enabled=["opencode", "google_ai"])

        with mock.patch.object(
            collector.google, "fetch_snapshot", lambda **kwargs: _snapshot("google_ai")
        ):
            payload = collector.collect(enabled=["google_ai"])

        self.assertEqual(set(payload["providers"]), {"google_ai"})
        cached = collector.cached_payload()
        self.assertEqual(set(cached["providers"]), {"opencode", "google_ai"})

    def test_state_file_is_private(self):
        state.save_state({"providers": {}, "internal": {}})
        path = os.path.join(self._tmp.name, "state.json")
        self.assertEqual(os.stat(path).st_mode & 0o777, 0o600)
        with open(path, encoding="utf-8") as handle:
            json.load(handle)


if __name__ == "__main__":
    unittest.main()
