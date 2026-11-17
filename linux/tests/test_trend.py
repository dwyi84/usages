import datetime as dt
import unittest

from aiusages import trend

from helpers import UTC


class TrendTests(unittest.TestCase):
    def test_empty_has_30_buckets(self):
        empty = trend.empty_trend()
        self.assertEqual(len(empty["daily_bars"]), 30)
        self.assertEqual(empty["daily_points"], [])

    def test_buckets_are_oldest_to_newest(self):
        now = dt.datetime(2026, 11, 17, 12, 0, tzinfo=UTC)
        result = trend.build_trend(
            spend_by_date={"2026-11-17": 1.0},
            tokens_by_date={"2026-11-17": 10},
            now=now,
            tz=UTC,
        )
        points = result["daily_points"]
        self.assertEqual(len(points), 30)
        self.assertEqual(points[0]["date"], "2026-10-19")
        self.assertEqual(points[-1]["date"], "2026-11-17")
        self.assertEqual(points[-1]["tokens"], 10)
        self.assertEqual(result["today_tokens"], 10)
        self.assertEqual(result["today_spend_usd"], 1.0)
        self.assertEqual(result["last_30_days_tokens"], 10)

    def test_normalisation_uses_peak_day(self):
        now = dt.datetime(2026, 11, 17, 12, 0, tzinfo=UTC)
        result = trend.build_trend(
            spend_by_date={},
            tokens_by_date={"2026-11-15": 100, "2026-11-16": 50},
            now=now,
            tz=UTC,
        )
        self.assertEqual(result["daily_bars"][-3], 1.0)
        self.assertEqual(result["daily_bars"][-2], 0.5)
        self.assertEqual(result["peak_label"], "11/15")
        self.assertEqual(result["peak_tokens"], 100)
        self.assertEqual(result["daily_avg_tokens"], int(150 / 30))

    def test_yesterday_bucket(self):
        now = dt.datetime(2026, 11, 17, 12, 0, tzinfo=UTC)
        result = trend.build_trend(
            spend_by_date={"2026-11-16": 3.0},
            tokens_by_date={"2026-11-16": 30},
            now=now,
            tz=UTC,
        )
        self.assertEqual(result["yesterday_spend_usd"], 3.0)
        self.assertEqual(result["yesterday_tokens"], 30)

    def test_steps_unit_hides_cost(self):
        now = dt.datetime(2026, 11, 17, 12, 0, tzinfo=UTC)
        result = trend.build_trend(
            spend_by_date={},
            tokens_by_date={"2026-11-17": 12},
            now=now,
            tz=UTC,
            unit="steps",
            cost_available=False,
        )
        self.assertEqual(result["unit"], "steps")
        self.assertFalse(result["cost_available"])


if __name__ == "__main__":
    unittest.main()
