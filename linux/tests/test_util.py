import datetime as dt
import unittest

from aiusages import util

from helpers import KST, UTC


class ParseTests(unittest.TestCase):
    def test_parses_fractional_seconds(self):
        parsed = util.parse_iso8601("2026-11-03T17:57:37.000Z")
        self.assertEqual(parsed, dt.datetime(2026, 11, 3, 17, 57, 37, tzinfo=UTC))

    def test_parses_plain_timestamps(self):
        parsed = util.parse_iso8601("2026-11-07T04:57:11Z")
        self.assertEqual(parsed, dt.datetime(2026, 11, 7, 4, 57, 11, tzinfo=UTC))

    def test_parses_microsecond_and_nanosecond_precision(self):
        self.assertEqual(
            util.parse_iso8601("2026-11-03T17:57:37.123456Z"),
            dt.datetime(2026, 11, 3, 17, 57, 37, 123456, tzinfo=UTC),
        )
        self.assertEqual(
            util.parse_iso8601("2026-11-03T17:57:37.123456789Z"),
            dt.datetime(2026, 11, 3, 17, 57, 37, 123456, tzinfo=UTC),
        )

    def test_accepts_offset_without_colon(self):
        parsed = util.parse_iso8601("2026-11-03T17:57:37+0900")
        self.assertEqual(parsed.utcoffset(), dt.timedelta(hours=9))

    def test_rejects_invalid_timestamps(self):
        for value in (None, "", "not-a-date", "2026-13-40T99:00:00Z"):
            with self.subTest(value=value):
                self.assertIsNone(util.parse_iso8601(value))


class CountdownTests(unittest.TestCase):
    def setUp(self):
        self.now = dt.datetime(2026, 11, 17, 12, 0, tzinfo=UTC)

    def test_days_and_hours(self):
        self.assertEqual(util.format_countdown("2026-11-19T14:30:00Z", True, self.now), "2일 2시간 후 리셋")
        self.assertEqual(util.format_countdown("2026-11-19T14:30:00Z", False, self.now), "Resets in 2d 2h")

    def test_under_a_day(self):
        self.assertEqual(util.format_countdown("2026-11-17T17:45:00Z", True, self.now), "5시간 45분 후 리셋")
        self.assertEqual(util.format_countdown("2026-11-17T17:45:00Z", False, self.now), "Resets in 5h 45m")

    def test_never_negative(self):
        self.assertEqual(util.format_countdown("2026-11-16T12:00:00Z", False, self.now), "Resets in 0h 0m")

    def test_unknown_quota(self):
        self.assertEqual(util.format_countdown(None, True), "쿼터 여유")
        self.assertEqual(util.format_countdown(None, False), "Quota available")


class StatusTests(unittest.TestCase):
    def test_status_thresholds(self):
        self.assertEqual(util.status_for_percent(100), "normal")
        self.assertEqual(util.status_for_percent(36), "normal")
        self.assertEqual(util.status_for_percent(35), "warning")
        self.assertEqual(util.status_for_percent(16), "warning")
        self.assertEqual(util.status_for_percent(15), "critical")
        self.assertEqual(util.status_for_percent(0), "critical")

    def test_clamp_percent(self):
        self.assertEqual(util.clamp_percent(-5), 0.0)
        self.assertEqual(util.clamp_percent(140), 100.0)
        self.assertEqual(util.clamp_percent("12.5"), 12.5)
        self.assertEqual(util.clamp_percent(None, default=7.0), 7.0)

    def test_fraction_to_percent(self):
        self.assertEqual(util.fraction_to_percent(0.5), 50.0)
        self.assertIsNone(util.fraction_to_percent(None))
        self.assertEqual(util.fraction_to_percent("0.25"), 25.0)


class BillingTests(unittest.TestCase):
    def test_clamps_day_31_to_last_day_of_november(self):
        now = dt.datetime(2026, 11, 17, 12, 0, tzinfo=KST)
        result = util.calculate_next_billing(31, now=now)
        self.assertEqual(result["days"], 12)  # 2026-11-30, noon-to-midnight truncates

    def test_rolls_into_next_month(self):
        now = dt.datetime(2026, 11, 17, 12, 0, tzinfo=KST)
        result = util.calculate_next_billing(5, now=now)
        self.assertEqual(result["days"], 17)  # 2026-12-05, noon-to-midnight truncates

    def test_today_shows_zero_days(self):
        now = dt.datetime(2026, 11, 17, 12, 0, tzinfo=KST)
        result = util.calculate_next_billing(17, now=now, korean=True)
        self.assertEqual(result["days"], 0)
        self.assertIn("오늘", result["date_string"])

    def test_unset_day_returns_empty(self):
        self.assertEqual(util.calculate_next_billing(0), {"date_string": "", "days": 0})
        self.assertEqual(util.calculate_next_billing(32), {"date_string": "", "days": 0})


if __name__ == "__main__":
    unittest.main()
