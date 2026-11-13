package com.melissasoft.aiusages.provider

import com.melissasoft.aiusages.model.DailyUsagePoint
import com.melissasoft.aiusages.model.UsageMetricUnit
import com.melissasoft.aiusages.model.UsageTrendSummary
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.max

/**
 * Shared 30-day usage trend aggregator used by OpenCode, Google AI, and OpenRouter
 * so date bucketing, normalization, and peak calculation live in one place.
 */
object TrendBuilder {
    private val isoDateFmt = DateTimeFormatter.ofPattern("yyyy-MM-dd")
    private val labelDateFmt = DateTimeFormatter.ofPattern("MM/dd")

    fun build30DaySummary(
        spendByDate: Map<String, Double>,
        tokensByDate: Map<String, Int>,
        zoneId: ZoneId,
        now: Instant = Instant.now(),
        metricUnit: UsageMetricUnit = UsageMetricUnit.TOKENS,
        costAvailable: Boolean = true,
        recentActivityLog: String = "",
        fallbackTodaySpend: Double? = null,
        fallbackMonthlySpend: Double? = null,
        hasPerDayActivity: Boolean = true
    ): UsageTrendSummary {
        val today = now.atZone(zoneId).toLocalDate()
        val yesterday = today.minusDays(1)
        val todayStr = today.format(isoDateFmt)
        val yesterdayStr = yesterday.format(isoDateFmt)

        val todaySpend = spendByDate[todayStr] ?: fallbackTodaySpend ?: 0.0
        val todayTokens = tokensByDate[todayStr] ?: 0
        val yesterdaySpend = spendByDate[yesterdayStr] ?: 0.0
        val yesterdayTokens = tokensByDate[yesterdayStr] ?: 0

        var last30Spend = 0.0
        var last30Tokens = 0
        val rawPoints = ArrayList<DailyUsagePoint>(30)

        for (offset in 29 downTo 0) {
            val targetDate: LocalDate = today.minusDays(offset.toLong())
            val dStr = targetDate.format(isoDateFmt)
            val lStr = targetDate.format(labelDateFmt)
            val spend = spendByDate[dStr] ?: 0.0
            val tok = tokensByDate[dStr] ?: 0
            last30Spend += spend
            last30Tokens += tok
            rawPoints.add(
                DailyUsagePoint(
                    dateString = dStr,
                    dateLabel = lStr,
                    spendUSD = spend,
                    tokens = tok,
                    normalized = 0.0
                )
            )
        }

        if (!hasPerDayActivity) {
            last30Spend = fallbackMonthlySpend ?: todaySpend
            last30Tokens = todayTokens
            if (rawPoints.isNotEmpty()) {
                val lastIdx = rawPoints.lastIndex
                rawPoints[lastIdx] = rawPoints[lastIdx].copy(
                    spendUSD = todaySpend,
                    tokens = todayTokens
                )
            }
        }

        val maxTok = max(rawPoints.maxOfOrNull { it.tokens } ?: 1, 1)
        val normalizedPoints = rawPoints.map { pt ->
            val norm = if (pt.tokens > 0) pt.tokens.toDouble() / maxTok.toDouble() else 0.0
            pt.copy(normalized = norm)
        }
        val dailyBars = normalizedPoints.map { it.normalized }

        val peak = normalizedPoints.maxByOrNull { it.tokens }
        val peakLabel = if (peak != null && peak.tokens > 0) peak.dateLabel else ""
        val peakTok = if (peak != null && peak.tokens > 0) peak.tokens else 0

        return UsageTrendSummary(
            todaySpendUSD = todaySpend,
            todayTokens = todayTokens,
            yesterdaySpendUSD = yesterdaySpend,
            yesterdayTokens = yesterdayTokens,
            last30DaysSpendUSD = last30Spend,
            last30DaysTokens = last30Tokens,
            dailyBars = dailyBars,
            dailyPoints = normalizedPoints,
            dailyAvgSpendUSD = last30Spend / 30.0,
            dailyAvgTokens = last30Tokens / 30,
            peakDateLabel = peakLabel,
            peakTokens = peakTok,
            recentActivityLog = recentActivityLog,
            metricUnit = metricUnit,
            costAvailable = costAvailable
        )
    }
}
