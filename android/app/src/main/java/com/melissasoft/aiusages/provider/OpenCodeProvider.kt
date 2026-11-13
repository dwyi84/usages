package com.melissasoft.aiusages.provider

import android.database.sqlite.SQLiteDatabase
import com.melissasoft.aiusages.model.GaugeStatus
import com.melissasoft.aiusages.model.OpenCodeWindows
import com.melissasoft.aiusages.model.ServiceType
import com.melissasoft.aiusages.model.ServiceUsageSnapshot
import com.melissasoft.aiusages.model.UsageMetricUnit
import com.melissasoft.aiusages.model.UsageTrendSummary
import com.melissasoft.aiusages.util.ISO8601Parser
import com.melissasoft.aiusages.util.L10n
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.util.Locale
import java.util.concurrent.TimeUnit
import kotlin.math.ceil
import kotlin.math.max

class OpenCodeProvider(
    private val client: OkHttpClient = defaultHttpClient(),
    private val usageUrl: String = "https://opencode.ai/zen/go/v1/usage"
) {
    @Volatile
    private var cachedSnapshot: ServiceUsageSnapshot? = null

    @Volatile
    private var rateLimitUntil: Instant? = null

    suspend fun fetchUsageSnapshot(
        token: String?,
        importedDbFile: File? = null,
        now: Instant = Instant.now()
    ): ServiceUsageSnapshot = withContext(Dispatchers.IO) {
        val cleanToken = token?.trim().orEmpty()
        if (cleanToken.isEmpty()) {
            return@withContext ServiceUsageSnapshot(
                service = ServiceType.OPEN_CODE,
                planName = "OpenCode Go",
                status = GaugeStatus.UNKNOWN,
                lastUpdated = now,
                isAvailable = false
            )
        }

        val limitUntil = rateLimitUntil
        if (limitUntil != null && now.isBefore(limitUntil)) {
            cachedSnapshot?.let { return@withContext it.copy(status = GaugeStatus.RATE_LIMITED) }
        }

        val trend = if (importedDbFile != null && importedDbFile.exists()) {
            readLocalUsageTrendFromDb(importedDbFile, now)
        } else {
            UsageTrendSummary()
        }

        val remote = fetchFromRemoteApi(cleanToken, trend, now)
        if (remote != null) {
            cachedSnapshot = remote
            rateLimitUntil = null
            return@withContext remote
        }

        cachedSnapshot?.let {
            return@withContext it.copy(
                status = if (rateLimitUntil?.isAfter(now) == true) GaugeStatus.RATE_LIMITED else GaugeStatus.WARNING
            )
        }

        ServiceUsageSnapshot(
            service = ServiceType.OPEN_CODE,
            planName = "OpenCode Go",
            status = if (rateLimitUntil?.isAfter(now) == true) GaugeStatus.RATE_LIMITED else GaugeStatus.WARNING,
            lastUpdated = now,
            isAvailable = true,
            trendSummary = trend
        )
    }

    private fun fetchFromRemoteApi(
        token: String,
        trend: UsageTrendSummary,
        now: Instant
    ): ServiceUsageSnapshot? {
        val request = Request.Builder()
            .url(usageUrl)
            .get()
            .header("Authorization", "Bearer $token")
            .header("Accept", "application/json")
            .build()

        return try {
            client.newCall(request).execute().use { response ->
                if (response.code == 429) {
                    val retrySec = response.header("Retry-After")?.toLongOrNull() ?: 300L
                    rateLimitUntil = now.plusSeconds(retrySec.coerceAtLeast(30L))
                    return null
                }
                if (!response.isSuccessful) return null
                val body = response.body?.string() ?: return null
                parseUsageJson(body, now, L10n.isKorean, trend)
            }
        } catch (_: Throwable) {
            null
        }
    }

    fun importFromFile(inputStream: InputStream, destDbFile: File): String? {
        val bytes = inputStream.readBytes()
        if (bytes.isEmpty()) return null
        val sqliteHeader = "SQLite format 3".toByteArray(Charsets.US_ASCII)
        val isSqlite = bytes.size >= sqliteHeader.size &&
            bytes.sliceArray(0 until sqliteHeader.size).contentEquals(sqliteHeader)

        if (isSqlite) {
            val tmp = File(destDbFile.parentFile, "${destDbFile.name}.tmp")
            tmp.writeBytes(bytes)
            val token = readTokenFromSqlite(tmp)
            if (!tmp.renameTo(destDbFile)) {
                tmp.copyTo(destDbFile, overwrite = true)
                tmp.delete()
            }
            return token
        }

        val text = bytes.toString(Charsets.UTF_8)
        return tokenFromAuthFileJson(text) ?: tokenFromCredentialJson(text)
    }

    private fun readTokenFromSqlite(dbFile: File): String? {
        var db: SQLiteDatabase? = null
        return try {
            db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
            val query = """
                SELECT value FROM credential
                WHERE integration_id IN ('opencode-go', 'opencode')
                   OR connector_id IN ('opencode-go', 'opencode')
                   OR label IN ('OpenCode Go', 'OpenCode', 'Default')
                ORDER BY active DESC, time_updated DESC
                LIMIT 20
            """.trimIndent()
            db.rawQuery(query, null).use { cursor ->
                while (cursor.moveToNext()) {
                    val jsonStr = cursor.getString(0) ?: continue
                    val tok = tokenFromCredentialJson(jsonStr)
                    if (tok != null) return tok
                }
            }
            null
        } catch (_: Throwable) {
            null
        } finally {
            db?.close()
        }
    }

    fun readLocalUsageTrendFromDb(
        dbFile: File,
        now: Instant = Instant.now(),
        zoneId: ZoneId = ZoneId.systemDefault()
    ): UsageTrendSummary {
        if (!dbFile.exists()) return UsageTrendSummary()
        var db: SQLiteDatabase? = null
        return try {
            db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
            val cutoffMs = now.minus(Duration.ofDays(35)).toEpochMilli()
            val query = """
                SELECT
                    date(time_created / 1000, 'unixepoch', 'localtime') as day,
                    coalesce(sum(json_extract(data, '$.cost')), 0.0) as spend,
                    coalesce(sum(
                        coalesce(json_extract(data, '$.tokens.input'), 0) +
                        coalesce(json_extract(data, '$.tokens.output'), 0) +
                        coalesce(json_extract(data, '$.tokens.reasoning'), 0) +
                        coalesce(json_extract(data, '$.tokens.cache.read'), 0) +
                        coalesce(json_extract(data, '$.tokens.cache.write'), 0)
                    ), 0) as tokens
                FROM session_message
                WHERE type = 'assistant' AND time_created >= ?
                GROUP BY day
                ORDER BY day DESC
                LIMIT 35
            """.trimIndent()
            val spendByDate = HashMap<String, Double>()
            val tokensByDate = HashMap<String, Int>()
            db.rawQuery(query, arrayOf(cutoffMs.toString())).use { c ->
                while (c.moveToNext()) {
                    val day = c.getString(0) ?: continue
                    spendByDate[day] = c.getDouble(1)
                    tokensByDate[day] = c.getLong(2).toInt()
                }
            }

            var recentLog = ""
            val logQuery = """
                SELECT coalesce(json_extract(data, '$.model.id'), 'opencode-go'), coalesce(json_extract(data, '$.cost'), 0.0)
                FROM session_message
                WHERE type = 'assistant' AND json_extract(data, '$.cost') > 0
                ORDER BY time_created DESC LIMIT 1
            """.trimIndent()
            db.rawQuery(logQuery, null).use { c ->
                if (c.moveToFirst()) {
                    val model = c.getString(0) ?: "opencode-go"
                    val cost = c.getDouble(1)
                    recentLog = if (L10n.isKorean) {
                        "최근 모델: $model ($${String.format(Locale.US, "%.4f", cost)})"
                    } else {
                        "Recent: $model ($${String.format(Locale.US, "%.4f", cost)})"
                    }
                }
            }
            if (recentLog.isEmpty()) {
                recentLog = if (L10n.isKorean) "최근 세션: OpenCode Go 활성" else "Recent: OpenCode Go Active"
            }

            TrendBuilder.build30DaySummary(
                spendByDate = spendByDate,
                tokensByDate = tokensByDate,
                zoneId = zoneId,
                now = now,
                metricUnit = UsageMetricUnit.TOKENS,
                costAvailable = true,
                recentActivityLog = recentLog
            )
        } catch (_: Throwable) {
            UsageTrendSummary()
        } finally {
            db?.close()
        }
    }

    companion object {
        private fun defaultHttpClient(): OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(6, TimeUnit.SECONDS)
            .readTimeout(6, TimeUnit.SECONDS)
            .build()

        fun tokenFromAuthFileJson(jsonString: String): String? {
            return try {
                val root = JSONObject(jsonString)
                val entry = root.optJSONObject("opencode-go") ?: root.optJSONObject("opencode")
                if (entry != null) tokenFromCredentialObject(entry) else null
            } catch (_: Throwable) {
                null
            }
        }

        fun tokenFromCredentialJson(jsonString: String): String? {
            return try {
                val obj = JSONObject(jsonString)
                tokenFromCredentialObject(obj)
            } catch (_: Throwable) {
                null
            }
        }

        fun tokenFromCredentialObject(obj: JSONObject): String? {
            val keys = listOf("access", "access_token", "accessToken", "key", "apiKey", "api_key", "token")
            for (k in keys) {
                if (obj.has(k) && !obj.isNull(k)) {
                    val value = obj.optString(k, "").trim()
                    if (value.isNotEmpty()) return value
                }
            }
            val nested = obj.optJSONObject("tokens")
            if (nested != null) {
                return tokenFromCredentialObject(nested)
            }
            return null
        }

        fun parseUsageJson(
            rawJson: String,
            now: Instant = Instant.now(),
            isKorean: Boolean = L10n.isKorean,
            trendSummary: UsageTrendSummary = UsageTrendSummary()
        ): ServiceUsageSnapshot? {
            return try {
                val json = JSONObject(rawJson)
                val usage = json.optJSONObject("usage") ?: return null
                val rolling = usage.optJSONObject("rolling") ?: return null
                val weekly = usage.optJSONObject("weekly") ?: return null
                val monthly = usage.optJSONObject("monthly") ?: return null

                val rollUsed = readNumber(rolling, "percent") ?: return null
                val weekUsed = readNumber(weekly, "percent") ?: return null
                val monthUsed = readNumber(monthly, "percent") ?: return null

                val rollRem = max(0.0, 100.0 - rollUsed)
                val weekRem = max(0.0, 100.0 - weekUsed)
                val monthRem = max(0.0, 100.0 - monthUsed)

                val rollResetIso = rolling.optString("resetsAt", "")
                val weekResetIso = weekly.optString("resetsAt", "")
                val monthResetIso = monthly.optString("resetsAt", "")

                val rollStr = resetLabel(formatCountdown(rollResetIso, now, isKorean), isKorean)
                val weekStr = resetLabel(formatCountdown(weekResetIso, now, isKorean), isKorean)
                val monthStr = resetLabel(formatCountdown(monthResetIso, now, isKorean), isKorean)
                val daysRem = calculateDaysRemaining(monthResetIso, now)

                val windows = OpenCodeWindows(
                    fiveHourRemainingPercent = rollRem,
                    fiveHourResetString = rollStr,
                    weeklyRemainingPercent = weekRem,
                    weeklyResetString = weekStr,
                    monthlyRemainingPercent = monthRem,
                    monthlyResetString = monthStr,
                    nextBillingDateString = monthStr,
                    daysUntilBilling = daysRem
                )

                val status = when {
                    monthRem <= 15.0 -> GaugeStatus.CRITICAL
                    monthRem <= 35.0 -> GaugeStatus.WARNING
                    else -> GaugeStatus.NORMAL
                }

                ServiceUsageSnapshot(
                    service = ServiceType.OPEN_CODE,
                    planName = "OpenCode Go",
                    remainingPercent = monthRem,
                    billingDateString = monthStr,
                    daysUntilBilling = daysRem,
                    status = status,
                    lastUpdated = now,
                    isAvailable = true,
                    openCodeWindows = windows,
                    trendSummary = trendSummary
                )
            } catch (_: Throwable) {
                null
            }
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

        private fun formatCountdown(isoString: String?, now: Instant, isKorean: Boolean): String {
            val target = ISO8601Parser.parseInstant(isoString) ?: return "-"
            val diffSec = max(0L, Duration.between(now, target).seconds)
            val days = diffSec / 86400L
            val hours = (diffSec % 86400L) / 3600L
            val mins = (diffSec % 3600L) / 60L
            return if (isKorean) {
                if (days > 0) "${days}일 ${hours}시간" else "${hours}시간 ${mins}분"
            } else {
                if (days > 0) "${days}d ${hours}h" else "${hours}h ${mins}m"
            }
        }

        private fun resetLabel(countdown: String, isKorean: Boolean): String {
            if (countdown == "-") return "-"
            return if (isKorean) "$countdown 후 리셋" else "Resets in $countdown"
        }

        private fun calculateDaysRemaining(isoString: String?, now: Instant): Int {
            val target = ISO8601Parser.parseInstant(isoString) ?: return 999
            val diffSec = Duration.between(now, target).seconds
            return max(0, ceil(diffSec / 86400.0).toInt())
        }
    }
}
