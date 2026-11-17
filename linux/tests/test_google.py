import datetime as dt
import json
import unittest

from aiusages import google
from aiusages.httpclient import HttpResult

from helpers import UTC

REST_PAYLOAD = {
    "groups": [
        {
            "displayName": "Gemini Models",
            "buckets": [
                {"bucketId": "gemini-weekly", "remainingFraction": 0.84, "resetTime": "2026-11-23T06:25:09Z"},
                {"bucketId": "gemini-5h", "remainingFraction": 1.0, "resetTime": "2026-11-17T11:04:57Z"},
            ],
        },
        {
            "displayName": "Claude and GPT models",
            "buckets": [
                {"bucketId": "3p-weekly", "remainingFraction": 1.0, "resetTime": "2026-11-24T01:55:19Z"},
                {"bucketId": "3p-5h", "remainingFraction": 1.0, "resetTime": "2026-11-17T11:04:57Z"},
            ],
        },
    ]
}

AGY_PAYLOAD = {
    "conversation_id": "",
    "status": "SUCCESS",
    "command": {
        "name": "usage",
        "data": {
            "groups": [
                {
                    "name": "Gemini Models",
                    "buckets": [
                        {
                            "id": "gemini-weekly",
                            "name": "Weekly Limit Remaining",
                            "window": "weekly",
                            "remaining_fraction": 0.836664080619812,
                            "reset_time": "2026-11-23T06:25:09Z",
                        },
                        {
                            "id": "gemini-5h",
                            "name": "Five Hour Limit Remaining",
                            "window": "5h",
                            "remaining_fraction": 1,
                            "reset_time": "2026-11-17T11:04:57Z",
                        },
                    ],
                },
                {
                    "name": "Claude and GPT models",
                    "buckets": [
                        {
                            "id": "3p-weekly",
                            "name": "Weekly Limit Remaining",
                            "window": "weekly",
                            "remaining_fraction": 1,
                            "reset_time": "2026-11-24T01:55:19Z",
                        }
                    ],
                },
                {
                    "name": "Gemini 4 Argon",
                    "buckets": [
                        {
                            "id": "argon-weekly",
                            "name": "Gemini 4 Argon Weekly Limit",
                            "window": "weekly",
                            "remaining_fraction": 0.34,
                            "reset_time": "2026-11-23T05:59:33Z",
                        }
                    ],
                },
            ]
        },
    },
}


class RestParsingTests(unittest.TestCase):
    def test_parses_groups(self):
        limits = google.parse_rest_quota(REST_PAYLOAD)
        self.assertAlmostEqual(limits["gemini_weekly"]["percent"], 84.0)
        self.assertEqual(limits["gemini_5h"]["percent"], 100.0)
        self.assertEqual(limits["claude_weekly"]["percent"], 100.0)
        self.assertEqual(limits["claude_5h"]["percent"], 100.0)
        self.assertNotIn("argon_weekly", limits)

    def test_rejects_empty_payloads(self):
        self.assertIsNone(google.parse_rest_quota({}))
        self.assertIsNone(google.parse_rest_quota({"groups": []}))
        self.assertIsNone(google.parse_agy_usage({"command": {"data": {}}}))


class AgyParsingTests(unittest.TestCase):
    def test_parses_usage_including_argon(self):
        limits = google.parse_agy_usage(AGY_PAYLOAD)
        self.assertEqual(limits["argon_weekly"]["percent"], 34.0)
        self.assertAlmostEqual(limits["gemini_weekly"]["percent"], 83.67, places=2)

    def test_parses_real_cli_output(self):
        output = {
            "conversation_id": "",
            "status": "SUCCESS",
            "command": {"name": "usage", "data": AGY_PAYLOAD["command"]["data"]},
        }
        self.assertIsNotNone(google.parse_agy_usage(json.loads(json.dumps(output))))


class MergeTests(unittest.TestCase):
    def test_overlay_wins_but_missing_keys_are_kept(self):
        rest = google.parse_rest_quota(REST_PAYLOAD)
        agy = google.parse_agy_usage(AGY_PAYLOAD)
        merged = google.merge_limits(agy, rest)
        self.assertEqual(merged["gemini_weekly"]["percent"], 84.0)
        self.assertEqual(merged["argon_weekly"]["percent"], 34.0)

    def test_overall_ignores_missing_groups(self):
        limits = google.parse_rest_quota(REST_PAYLOAD)
        self.assertEqual(google.overall_remaining(limits), 84.0)

    def test_overall_falls_back_to_five_hour(self):
        limits = {"gemini_5h": {"percent": 70.0}, "claude_5h": {"percent": 55.0}}
        self.assertEqual(google.overall_remaining(limits), 55.0)

    def test_overall_zero_only_when_unknown(self):
        self.assertEqual(google.overall_remaining({}), 0.0)


class SnapshotTests(unittest.TestCase):
    def test_missing_group_is_not_reported_as_zero(self):
        limits = google.parse_rest_quota(REST_PAYLOAD)
        snapshot = google._snapshot(
            limits,
            korean=False,
            billing_day=0,
            status_override=None,
            error=None,
            now=dt.datetime(2026, 11, 17, 6, 0, tzinfo=UTC),
        )
        keys = [row["key"] for row in snapshot["rows"]]
        self.assertNotIn("google_argon_weekly", keys)
        self.assertTrue(snapshot["available"])
        self.assertEqual(snapshot["status"], "normal")
        self.assertEqual(snapshot["billing"]["date_string"], "")

    def test_includes_argon_and_billing(self):
        limits = google.merge_limits(google.parse_agy_usage(AGY_PAYLOAD), google.parse_rest_quota(REST_PAYLOAD))
        now = dt.datetime(2026, 11, 17, 6, 0, tzinfo=UTC)
        snapshot = google._snapshot(
            limits,
            korean=True,
            billing_day=12,
            status_override=None,
            error=None,
            now=now,
        )
        keys = [row["key"] for row in snapshot["rows"]]
        self.assertIn("google_argon_weekly", keys)
        # Argon (34%) is the lowest weekly group, so it drives the overall value.
        self.assertEqual(snapshot["primary_percent"], 34.0)
        self.assertIn("매월 12일", snapshot["billing"]["date_string"])


class TokenTests(unittest.TestCase):
    def test_refresh_is_cached(self):
        cache = {}
        credentials = {"refresh_token": "rt", "access_token": "old"}
        calls = []

        def fake_request_json(*args, **kwargs):
            calls.append(kwargs)
            return HttpResult(status=200, data={"access_token": "new", "expires_in": 3600})

        original = google.request_json
        google.request_json = fake_request_json
        try:
            now = dt.datetime(2026, 11, 17, 6, 0, tzinfo=UTC)
            self.assertEqual(google.refresh_access_token(credentials, cache, now=now), "new")
            self.assertEqual(google.refresh_access_token(credentials, cache, now=now), "new")
        finally:
            google.request_json = original

        self.assertEqual(len(calls), 1)
        self.assertEqual(cache["access_token"], "new")

    def test_missing_credentials_reports_no_credentials(self):
        original_credentials = google.secrets.google_credentials
        original_agy = google.find_agy
        google.secrets.google_credentials = lambda: None
        google.find_agy = lambda: None
        try:
            snapshot = google.fetch_snapshot(korean=True, billing_day=0)
        finally:
            google.secrets.google_credentials = original_credentials
            google.find_agy = original_agy
        self.assertFalse(snapshot["available"])
        self.assertEqual(snapshot["error"], "no_credentials")


if __name__ == "__main__":
    unittest.main()
