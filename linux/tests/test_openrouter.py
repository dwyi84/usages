import datetime as dt
import unittest
from unittest import mock

from aiusages import openrouter

from helpers import UTC


class ParsingTests(unittest.TestCase):
    def test_credits_balance(self):
        payload = {"data": {"total_credits": 20.0, "total_usage": 7.5}}
        self.assertEqual(openrouter.parse_credits(payload), 12.5)

    def test_balance_never_negative(self):
        payload = {"data": {"total_credits": 1.0, "total_usage": 5.0}}
        self.assertEqual(openrouter.parse_credits(payload), 0.0)

    def test_key_info_fields(self):
        payload = {
            "data": {
                "usage": 123.0,
                "usage_daily": 1.5,
                "usage_weekly": 9.0,
                "usage_monthly": 30.0,
                "prompt_tokens": 1000,
                "completion_tokens": 200,
            }
        }
        info = openrouter.parse_key_info(payload)
        self.assertEqual(info["usage_daily"], 1.5)
        self.assertEqual(info["usage_monthly"], 30.0)
        self.assertEqual(info["prompt_tokens"], 1000)
        self.assertEqual(info["completion_tokens"], 200)

    def test_activity_rows(self):
        payload = {
            "data": [
                {"date": "2026-11-16", "usage": 1.25, "prompt_tokens": 100, "completion_tokens": 50},
                {"date": "2026-11-16", "usage": 0.75, "prompt_tokens": 10, "completion_tokens": 5},
            ]
        }
        rows = openrouter.parse_activity(payload)
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]["tokens"], 150)


class TrendTests(unittest.TestCase):
    def test_activity_uses_utc_buckets(self):
        now = dt.datetime(2026, 11, 17, 1, 0, tzinfo=UTC)
        activity = [{"date": "2026-11-16", "usage": 2.0, "tokens": 200}]
        trend = openrouter.build_trend(activity, None, korean=False, now=now)
        self.assertEqual(trend["yesterday_spend_usd"], 2.0)
        self.assertEqual(trend["today_spend_usd"], 0.0)
        self.assertEqual(trend["last_30_days_spend_usd"], 2.0)

    def test_without_activity_uses_key_counters(self):
        now = dt.datetime(2026, 11, 17, 1, 0, tzinfo=UTC)
        key_info = {
            "usage_daily": 1.0,
            "usage_weekly": 4.0,
            "usage_monthly": 12.0,
            "usage_total": 99.0,
            "prompt_tokens": 10,
            "completion_tokens": 5,
        }
        trend = openrouter.build_trend([], key_info, korean=True, now=now)
        self.assertEqual(trend["today_spend_usd"], 1.0)
        self.assertEqual(trend["last_30_days_spend_usd"], 12.0)
        self.assertEqual(trend["last_30_days_tokens"], 0)
        self.assertEqual(trend["daily_points"][-1]["spend_usd"], 1.0)
        self.assertIn("프롬프트", trend["recent_log"])


class SnapshotTests(unittest.TestCase):
    def test_rows_use_formatted_values(self):
        def fake_request(url, key):
            return type(
                "Result",
                (),
                {
                    "status": 200,
                    "error": None,
                    "data": {
                        "data": {
                            "total_credits": 20.0,
                            "total_usage": 5.0,
                            "usage": 5.0,
                            "usage_daily": 0.5,
                            "usage_monthly": 5.0,
                            "prompt_tokens": 100,
                            "completion_tokens": 20,
                        }
                    },
                },
            )()

        with mock.patch.object(openrouter.secrets, "openrouter_key", lambda: "sk-or-test"):
            with mock.patch.object(openrouter, "_request", fake_request):
                snapshot = openrouter.fetch_snapshot(korean=False)

        self.assertTrue(snapshot["connected"])
        self.assertEqual(snapshot["primary_percent"], 100.0)
        values = {row["key"]: row["value"] for row in snapshot["rows"]}
        self.assertEqual(values["balance"], "$15.00")
        self.assertEqual(values["tokens"], "120")

    def test_missing_key(self):
        with mock.patch.object(openrouter.secrets, "openrouter_key", lambda: None):
            snapshot = openrouter.fetch_snapshot(korean=False)
        self.assertFalse(snapshot["available"])
        self.assertEqual(snapshot["error"], "missing_key")


if __name__ == "__main__":
    unittest.main()
