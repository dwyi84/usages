import datetime as dt
import json
import os
import sqlite3
import tempfile
import unittest
from unittest import mock

from aiusages import opencode

from helpers import UTC


class CredentialTests(unittest.TestCase):
    def test_reads_supported_credential_shapes(self):
        for raw in (
            json.dumps({"type": "key", "key": "oc_sk_abc"}),
            json.dumps({"type": "oauth", "access": "oauth-abc"}),
            json.dumps({"tokens": {"access_token": "nested-abc"}}),
            json.dumps({"apiKey": "camel-abc"}),
        ):
            with self.subTest(raw=raw):
                self.assertTrue(opencode.token_from_credential_json(raw))

    def test_prefers_access_token_when_both_shapes_present(self):
        raw = json.dumps({"access": "oauth", "key": "api"})
        self.assertEqual(opencode.token_from_credential_json(raw), "oauth")

    def test_prefers_nested_access_token_and_trims(self):
        raw = json.dumps({"tokens": {"access_token": "  nested  "}})
        self.assertEqual(opencode.token_from_credential_json(raw), "nested")

    def test_rejects_malformed_credentials(self):
        for raw in ("", "not json", "{}", '{"key": "   "}', "[]"):
            with self.subTest(raw=raw):
                self.assertIsNone(opencode.token_from_credential_json(raw))

    def test_reads_token_from_database(self):
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "opencode.db")
            connection = sqlite3.connect(path)
            connection.execute(
                "CREATE TABLE credential (id TEXT, integration_id TEXT, label TEXT, active INTEGER, "
                "time_updated INTEGER, value TEXT)"
            )
            connection.execute(
                "INSERT INTO credential VALUES ('1', 'opencode-go', 'OpenCode Go', 1, 100, ?)",
                (json.dumps({"type": "key", "key": "oc_sk_db"}),),
            )
            connection.execute(
                "INSERT INTO credential VALUES ('2', 'other', 'Other', 1, 200, ?)",
                (json.dumps({"key": "nope"}),),
            )
            connection.commit()
            connection.close()

            self.assertEqual(opencode.read_token_from_db(opencode.Path(path)), "oc_sk_db")

    def test_missing_database_returns_none(self):
        self.assertIsNone(opencode.read_token_from_db(opencode.Path("/nonexistent/opencode.db")))


class UsageTests(unittest.TestCase):
    def test_parses_usage_payload(self):
        payload = {
            "usage": {
                "rolling": {"percent": 5, "resetsAt": "2026-11-17T10:52:13.000Z"},
                "weekly": {"percent": 25, "resetsAt": "2026-11-23T00:00:00.000Z"},
                "monthly": {"percent": 9, "resetsAt": "2026-12-08T22:26:38.000Z"},
            }
        }
        windows = opencode.parse_usage_payload(payload)
        self.assertEqual(windows["five_hour"]["remaining_percent"], 95.0)
        self.assertEqual(windows["weekly"]["remaining_percent"], 75.0)
        self.assertEqual(windows["monthly"]["remaining_percent"], 91.0)

    def test_rejects_partial_payload(self):
        payload = {"usage": {"rolling": {"percent": 5}}}
        self.assertIsNone(opencode.parse_usage_payload(payload))

    def test_snapshot_rows_and_billing(self):
        payload = {
            "usage": {
                "rolling": {"percent": 0, "resetsAt": "2026-11-17T10:52:13.000Z"},
                "weekly": {"percent": 1, "resetsAt": "2026-11-23T00:00:00.000Z"},
                "monthly": {"percent": 9, "resetsAt": "2026-12-08T22:26:38.000Z"},
            }
        }
        now = dt.datetime(2026, 11, 17, 6, 0, tzinfo=UTC)
        snapshot = opencode.snapshot_from_payload(payload, korean=True, now=now)
        self.assertTrue(snapshot["available"])
        self.assertEqual(snapshot["primary_percent"], 91.0)
        self.assertEqual(
            [row["key"] for row in snapshot["rows"]],
            ["opencode_5h", "opencode_weekly", "opencode_monthly"],
        )
        self.assertEqual(snapshot["billing"]["days"], 21)


def _make_opencode_db(path):
    connection = sqlite3.connect(path)
    connection.execute(
        "CREATE TABLE session_message (id TEXT, session_id TEXT, type TEXT, seq INTEGER, "
        "time_created INTEGER, time_updated INTEGER, data TEXT)"
    )
    now_ms = int(dt.datetime(2026, 11, 17, 3, 0, tzinfo=UTC).timestamp() * 1000)
    rows = [
        ("a1", "assistant", now_ms, {"tokens": {"input": 10, "output": 5}, "cost": 0.0}),
        ("a2", "assistant", now_ms - 1000, {"tokens": {"cache": {"read": 100}, "reasoning": 2}, "cost": 0.0}),
        ("u1", "user", now_ms, {}),
        ("old", "assistant", now_ms - 40 * 86400 * 1000, {"tokens": {"input": 999}}),
    ]
    for row_id, kind, created, data in rows:
        connection.execute(
            "INSERT INTO session_message VALUES (?, 's1', ?, 0, ?, 0, ?)",
            (row_id, kind, created, json.dumps(data)),
        )
    connection.commit()
    connection.close()


class TrendTests(unittest.TestCase):
    def test_counts_all_token_counters(self):
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "opencode.db")
            _make_opencode_db(path)
            with mock.patch.dict(os.environ, {"AIUSAGES_OPENCODE_DB": path}):
                now = dt.datetime(2026, 11, 17, 6, 0, tzinfo=UTC)
                trend = opencode.local_trend(korean=False, now=now)

        # input+output (15) + cache read (100) + reasoning (2); the 40-day-old row is excluded.
        self.assertEqual(trend["today_tokens"], 117)
        self.assertEqual(len(trend["daily_bars"]), 30)
        self.assertGreater(sum(trend["daily_bars"]), 0)


if __name__ == "__main__":
    unittest.main()
