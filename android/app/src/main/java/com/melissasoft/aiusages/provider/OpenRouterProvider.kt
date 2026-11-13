package com.melissasoft.aiusages.provider

import com.melissasoft.aiusages.model.GaugeStatus
import com.melissasoft.aiusages.model.TokenCostSnapshot
import com.melissasoft.aiusages.model.UsageMetricUnit
import com.melissasoft.aiusages.model.UsageTrendSummary
import com.melissasoft.aiusages.util.L10n
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneOffset
import java.util.concurrent.TimeUnit
import kotlin.math.max

class OpenRouterProvider(
    private val client: OkHttpClient = defaultHttpClient(),
    private val baseUrl: String = "https://openrouter.ai/api/v1"
) {
    @Volatile
    private var cachedSnapshot = TokenCostSnapshot(
        providerId = "openrouter",
        providerName = "OpenRouter",
        isConnected = false
    )

    data class KeyInfoResult(
        val usageDaily: Double,
        val usageWeekly: Double,
        val usageMonthly: Double,
        val usageTotal: Double,
        val promptTokens: Int,
        val completionTokens: Int
    ) {
        val lifetimeTokens: Int get() = promptTokens + completionTokens
    }

    data class ActivityRow(
        val date: String,
        val usage: Double,
        val tokens: Int
    )

    suspend fun fetchSnapshot(
        apiKey: String?,
        now: Instant = Instant.now()
    ): TokenCostSnapshot = withContext(Dispatchers.IO) {
        val key = apiKey?.trim().orEmpty()
        if (key.isEmpty()) {
            return@withContext TokenCostSnapshot(
                providerId = "openrouter",
                providerName = "OpenRouter",
                isConnected = false,
                lastUpdated = now
            )
        }

        return@withContext try {
            coroutineScope {
                val creditsDef = async { fetchCredits(key) }
                val keyDef = async { fetchKeyInfo(key) }
                val activityDef = async { fetchActivity(key) }

                val credits = creditsDef.await()
                val keyInfo = keyDef.await()
                val activityRows = activityDef.await()

                if (credits == null && keyInfo == null) {
                    return@coroutineScope cachedSnapshot.copy(status = GaugeStatus.WARNING)
                }

                val balance = credits ?: 0.0
                val trend = buildTrendSummary(activityRows, keyInfo, now, L10n.isKorean)
                val monthSpend = keyInfo?.usageMonthly ?: trend.last30DaysSpendUSD

                val snapshot = TokenCostSnapshot(
                    providerId = "openrouter",
                    providerName = "OpenRouter",
                    balanceUSD = balance,
                    todaySpendUSD = trend.todaySpendUSD,
                    monthSpendUSD = monthSpend,
                    totalTokens = keyInfo?.lifetimeTokens ?: trend.last30DaysTokens,
                    promptTokens = keyInfo?.promptTokens ?: 0,
                    completionTokens = keyInfo?.completionTokens ?: 0,
                    cachedTokens = 0,
                    requestsCount = 0,
                    status = if (balance <= 1.0) GaugeStatus.WARNING else GaugeStatus.NORMAL,
                    lastUpdated = now,
                    isConnected = true,
                    trendSummary = trend
                )
                cachedSnapshot = snapshot
                snapshot
            }
        } catch (_: Throwable) {
            cachedSnapshot.copy(status = GaugeStatus.WARNING)
        }
    }

    private fun fetchCredits(key: String): Double? {
        val req = Request.Builder()
            .url("$baseUrl/credits")
            .get()
            .header("Authorization", "Bearer $key")
            .header("Accept", "application/json")
            .build()
        return try {
            client.newCall(req).execute().use { resp ->
                if (!resp.isSuccessful) return null
                parseCreditsJson(resp.body?.string() ?: return null)
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun fetchKeyInfo(key: String): KeyInfoResult? {
        val req = Request.Builder()
            .url("$baseUrl/key")
            .get()
            .header("Authorization", "Bearer $key")
            .header("Accept", "application/json")
            .build()
        return try {
            client.newCall(req).execute().use { resp ->
                if (!resp.isSuccessful) return null
                parseKeyInfoJson(resp.body?.string() ?: return null)
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun fetchActivity(key: String): List<ActivityRow> {
        val req = Request.Builder()
            .url("$baseUrl/activity")
            .get()
            .header("Authorization", "Bearer $key")
            .header("Accept", "application/json")
            .build()
        return try {
            client.newCall(req).execute().use { resp ->
                if (!resp.isSuccessful) return emptyList()
                parseActivityJson(resp.body?.string() ?: return emptyList())
            }
        } catch (_: Throwable) {
            emptyList()
        }
    }

    companion object {
        private fun defaultHttpClient(): OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(6, TimeUnit.SECONDS)
            .readTimeout(6, TimeUnit.SECONDS)
            .build()

        fun parseCreditsJson(rawJson: String): Double? {
            return try {
                val root = JSONObject(rawJson)
                val data = root.optJSONObject("data") ?: return null
                val total = readNumber(data, "total_credits") ?: 0.0
                val usage = readNumber(data, "total_usage") ?: 0.0
                max(0.0, total - usage)
            } catch (_: Throwable) {
                null
            }
        }

        fun parseKeyInfoJson(rawJson: String): KeyInfoResult? {
            return try {
                val root = JSONObject(rawJson)
                val data = root.optJSONObject("data") ?: return null
                KeyInfoResult(
                    usageDaily = readNumber(data, "usage_daily") ?: 0.0,
                    usageWeekly = readNumber(data, "usage_weekly") ?: 0.0,
                    usageMonthly = readNumber(data, "usage_monthly") ?: 0.0,
                    usageTotal = readNumber(data, "usage") ?: 0.0,
                    promptTokens = (readNumber(data, "prompt_tokens") ?: 0.0).toInt(),
                    completionTokens = (readNumber(data, "completion_tokens") ?: 0.0).toInt()
                )
            } catch (_: Throwable) {
                null
            }
        }

        fun parseActivityJson(rawJson: String): List<ActivityRow> {
            return try {
                val root = JSONObject(rawJson)
                val arr = root.optJSONArray("data") ?: return emptyList()
                buildList {
                    for (i in 0 until arr.length()) {
                        val item = arr.getJSONObject(i)
                        val date = item.optString("date", "")
                        if (date.isBlank()) continue
                        val usage = readNumber(item, "usage") ?: 0.0
                        val prompt = (readNumber(item, "prompt_tokens") ?: 0.0).toInt()
                        val completion = (readNumber(item, "completion_tokens") ?: 0.0).toInt()
                        add(ActivityRow(date = date, usage = usage, tokens = prompt + completion))
                    }
                }
            } catch (_: Throwable) {
                emptyList()
            }
        }

        fun buildTrendSummary(
            activityRows: List<ActivityRow>,
            keyInfo: KeyInfoResult?,
            now: Instant = Instant.now(),
            isKorean: Boolean = L10n.isKorean
        ): UsageTrendSummary {
            val spendByDate = HashMap<String, Double>()
            val tokensByDate = HashMap<String, Int>()
            for (row in activityRows) {
                spendByDate[row.date] = (spendByDate[row.date] ?: 0.0) + row.usage
                tokensByDate[row.date] = (tokensByDate[row.date] ?: 0) + row.tokens
            }

            val hasActivity = activityRows.isNotEmpty()
            val todaySpend = keyInfo?.usageDaily ?: 0.0
            var monthlyFallback = keyInfo?.usageMonthly ?: 0.0
            if (monthlyFallback <= 0.0) monthlyFallback = keyInfo?.usageWeekly ?: 0.0
            if (monthlyFallback <= 0.0) monthlyFallback = todaySpend

            val recentLog = if (keyInfo != null && keyInfo.usageTotal > 0.0) {
                if (isKorean) {
                    "프롬프트: ${keyInfo.promptTokens} · 완성: ${keyInfo.completionTokens}"
                } else {
                    "Prompt: ${keyInfo.promptTokens} · Comp: ${keyInfo.completionTokens}"
                }
            } else {
                if (isKorean) "API 키 정상 연동됨" else "API Key Connected"
            }

            return TrendBuilder.build30DaySummary(
                spendByDate = spendByDate,
                tokensByDate = tokensByDate,
                zoneId = ZoneOffset.UTC,
                now = now,
                metricUnit = UsageMetricUnit.TOKENS,
                costAvailable = true,
                recentActivityLog = recentLog,
                fallbackTodaySpend = todaySpend,
                fallbackMonthlySpend = monthlyFallback,
                hasPerDayActivity = hasActivity
            )
        }

        private fun readNumber(obj: JSONObject, key: String): Double? {
            if (!obj.has(key) || obj.isNull(key)) return null
            val raw = obj.get(key)
            return when (raw) {
                is Number -> raw.toDouble()
                is String -> raw.toDoubleOrNull()
                else -> null
            }
        }
    }
}
