package com.melissasoft.aiusages.model

import androidx.annotation.DrawableRes
import androidx.compose.ui.graphics.Color
import com.melissasoft.aiusages.R
import com.melissasoft.aiusages.util.L10n
import java.time.Instant

enum class ServiceType(val displayName: String) {
    OPEN_CODE("OpenCode Go"),
    GOOGLE_AI("Google AI Pro"),
    OPEN_ROUTER("OpenRouter"),
    CODEX("Codex"),
    CLAUDE("Claude"),
    CURSOR("Cursor"),
    COPILOT("Copilot"),
    PERPLEXITY("Perplexity"),
    DEEPSEEK("DeepSeek")
}

enum class ProviderCategory {
    QUOTA,
    TOKEN_AND_COST
}

enum class GaugeStatus(val colorValue: Long) {
    NORMAL(0xFF2ED159),
    WARNING(0xFFFF9E0D),
    CRITICAL(0xFFFF453A),
    RATE_LIMITED(0xFFAF52DE),
    ERROR(0xFF8E8E93),
    UNKNOWN(0xFF8E8E93);

    val composeColor: Color
        get() = Color(colorValue)
}

data class ProviderDescriptor(
    val id: String,
    val name: String,
    val category: ProviderCategory,
    val isDetected: Boolean,
    val isEnabled: Boolean
)

data class ProviderKeySpec(
    val id: String,
    val name: String,
    val envKeyName: String,
    val keyPrefix: String,
    val category: ProviderCategory
) {
    companion object {
        val genericSpecs: Map<String, ProviderKeySpec> = listOf(
            ProviderKeySpec("codex", "Codex", "OPENAI_API_KEY", "sk-", ProviderCategory.TOKEN_AND_COST),
            ProviderKeySpec("claude", "Claude", "ANTHROPIC_API_KEY", "sk-ant-", ProviderCategory.QUOTA),
            ProviderKeySpec("copilot", "Copilot", "GITHUB_TOKEN", "ghp_", ProviderCategory.QUOTA),
            ProviderKeySpec("perplexity", "Perplexity", "PERPLEXITY_API_KEY", "pplx-", ProviderCategory.TOKEN_AND_COST),
            ProviderKeySpec("deepseek", "DeepSeek", "DEEPSEEK_API_KEY", "sk-", ProviderCategory.TOKEN_AND_COST)
        ).associateBy { it.id }

        val defaultPopularityOrder: List<String> = listOf(
            "codex",
            "claude",
            "cursor",
            "google_ai",
            "opencode",
            "openrouter",
            "copilot",
            "perplexity",
            "deepseek"
        )
    }
}

enum class BrandIcon(
    @DrawableRes val drawableRes: Int,
    val isMulticolor: Boolean,
    val tintColor: Color?
) {
    OPEN_CODE(R.drawable.ic_brand_opencode, false, null),
    GOOGLE_AI(R.drawable.ic_brand_google_ai, true, Color(0xFF4285F5)),
    OPEN_ROUTER(R.drawable.ic_brand_openrouter, false, Color(0xFF475468)),
    CODEX(R.drawable.ic_brand_codex, true, Color(0xFF0FA37F)),
    CLAUDE(R.drawable.ic_brand_claude, false, Color(0xFFCC6642)),
    CURSOR(R.drawable.ic_brand_cursor, false, null),
    COPILOT(R.drawable.ic_brand_copilot, false, null),
    PERPLEXITY(R.drawable.ic_brand_perplexity, false, Color(0xFF0D8CA3)),
    DEEPSEEK(R.drawable.ic_brand_deepseek, false, Color(0xFF5787FF));

    companion object {
        fun fromProviderId(id: String): BrandIcon = when (id) {
            "opencode" -> OPEN_CODE
            "google_ai" -> GOOGLE_AI
            "openrouter" -> OPEN_ROUTER
            "codex" -> CODEX
            "claude" -> CLAUDE
            "cursor" -> CURSOR
            "copilot" -> COPILOT
            "perplexity" -> PERPLEXITY
            "deepseek" -> DEEPSEEK
            else -> CODEX
        }
    }
}

data class OpenCodeWindows(
    val fiveHourRemainingPercent: Double = 0.0,
    val fiveHourResetString: String = "-",
    val weeklyRemainingPercent: Double = 0.0,
    val weeklyResetString: String = "-",
    val monthlyRemainingPercent: Double = 0.0,
    val monthlyResetString: String = "-",
    val nextBillingDateString: String = "",
    val daysUntilBilling: Int = 999
)

/**
 * Percent fields are nullable on purpose: the quota API only returns groups
 * present for the signed-in account (Argon is frequently absent).
 */
data class GoogleAIGroupLimits(
    val geminiWeeklyRemainingPercent: Double? = null,
    val geminiWeeklyResetString: String = "-",
    val geminiFiveHourRemainingPercent: Double? = null,
    val geminiFiveHourResetString: String = "-",
    val claudeWeeklyRemainingPercent: Double? = null,
    val claudeWeeklyResetString: String = "-",
    val claudeFiveHourRemainingPercent: Double? = null,
    val claudeFiveHourResetString: String = "-",
    val argonWeeklyRemainingPercent: Double? = null,
    val argonWeeklyResetString: String = "-",
    val nextBillingDateString: String = "",
    val daysUntilBilling: Int = 0
) {
    val overallRemainingPercent: Double
        get() {
            val weekly = listOfNotNull(
                geminiWeeklyRemainingPercent,
                claudeWeeklyRemainingPercent,
                argonWeeklyRemainingPercent
            )
            if (weekly.isNotEmpty()) return weekly.min()
            val fiveHour = listOfNotNull(
                geminiFiveHourRemainingPercent,
                claudeFiveHourRemainingPercent
            )
            return fiveHour.minOrNull() ?: 0.0
        }

    val hasAnyKnownQuota: Boolean
        get() = geminiWeeklyRemainingPercent != null ||
            geminiFiveHourRemainingPercent != null ||
            claudeWeeklyRemainingPercent != null ||
            claudeFiveHourRemainingPercent != null ||
            argonWeeklyRemainingPercent != null
}

data class DailyUsagePoint(
    val dateString: String = "",
    val dateLabel: String = "",
    val spendUSD: Double = 0.0,
    val tokens: Int = 0,
    val normalized: Double = 0.0
)

enum class UsageMetricUnit {
    TOKENS,
    STEPS;

    val label: String
        get() = when (this) {
            TOKENS -> if (L10n.isKorean) "토큰" else "tokens"
            STEPS -> if (L10n.isKorean) "스텝" else "steps"
        }

    val title: String
        get() = when (this) {
            TOKENS -> L10n.totalTokens
            STEPS -> L10n.totalSteps
        }
}

data class UsageTrendSummary(
    val todaySpendUSD: Double = 0.0,
    val todayTokens: Int = 0,
    val yesterdaySpendUSD: Double = 0.0,
    val yesterdayTokens: Int = 0,
    val last30DaysSpendUSD: Double = 0.0,
    val last30DaysTokens: Int = 0,
    val dailyBars: List<Double> = List(30) { 0.0 },
    val dailyPoints: List<DailyUsagePoint> = emptyList(),
    val dailyAvgSpendUSD: Double = last30DaysSpendUSD / 30.0,
    val dailyAvgTokens: Int = last30DaysTokens / 30,
    val peakDateLabel: String = "",
    val peakTokens: Int = 0,
    val recentActivityLog: String = "",
    val metricUnit: UsageMetricUnit = UsageMetricUnit.TOKENS,
    val costAvailable: Boolean = true
)

data class ServiceUsageSnapshot(
    val service: ServiceType,
    val planName: String = "",
    val remainingPercent: Double = 0.0,
    val billingDateString: String = "",
    val daysUntilBilling: Int = 999,
    val status: GaugeStatus = GaugeStatus.UNKNOWN,
    val lastUpdated: Instant = Instant.now(),
    val isAvailable: Boolean = false,
    val openCodeWindows: OpenCodeWindows = OpenCodeWindows(),
    val googleGroups: GoogleAIGroupLimits = GoogleAIGroupLimits(),
    val trendSummary: UsageTrendSummary = UsageTrendSummary(),
    val statusMessage: String? = null
)

data class TokenCostSnapshot(
    val providerId: String = "openrouter",
    val providerName: String = "OpenRouter",
    val balanceUSD: Double = 0.0,
    val todaySpendUSD: Double = 0.0,
    val monthSpendUSD: Double = 0.0,
    val totalTokens: Int = 0,
    val promptTokens: Int = 0,
    val completionTokens: Int = 0,
    val cachedTokens: Int = 0,
    val requestsCount: Int = 0,
    val status: GaugeStatus = GaugeStatus.NORMAL,
    val lastUpdated: Instant = Instant.now(),
    val isConnected: Boolean = false,
    val trendSummary: UsageTrendSummary = UsageTrendSummary()
)

data class ReleaseInfo(
    val version: String,
    val htmlUrl: String,
    val apkDownloadUrl: String?
)
