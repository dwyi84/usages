package com.melissasoft.aiusages.provider

import android.database.sqlite.SQLiteDatabase
import java.util.Base64
import com.melissasoft.aiusages.model.GaugeStatus
import com.melissasoft.aiusages.model.GoogleAIGroupLimits
import com.melissasoft.aiusages.model.ServiceType
import com.melissasoft.aiusages.model.ServiceUsageSnapshot
import com.melissasoft.aiusages.model.UsageMetricUnit
import com.melissasoft.aiusages.model.UsageTrendSummary
import com.melissasoft.aiusages.util.ISO8601Parser
import com.melissasoft.aiusages.util.L10n
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.FormBody
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.util.concurrent.TimeUnit
import kotlin.math.max

data class GoogleOAuthBundle(
    val accessToken: String,
    val refreshToken: String? = null,
    val clientId: String? = null,
    val clientSecret: String? = null,
    val email: String? = null
) {
    fun toJsonString(): String {
        val tokenObj = JSONObject().apply {
            put("access_token", accessToken)
            if (!refreshToken.isNullOrBlank()) put("refresh_token", refreshToken)
        }
        return JSONObject().apply {
            put("token", tokenObj)
            if (!clientId.isNullOrBlank()) put("client_id", clientId)
            if (!clientSecret.isNullOrBlank()) put("client_secret", clientSecret)
            if (!email.isNullOrBlank()) put("email", email)
        }.toString()
    }
}

class GoogleAIProvider(
    private val client: OkHttpClient = defaultHttpClient(),
    private val endpoints: List<String> = listOf(
        "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
        "https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary"
    ),
    private val oauthTokenUrl: String = "https://oauth2.googleapis.com/token"
) {
    @Volatile
    private var cachedLimits = GoogleAIGroupLimits()

    @Volatile
    private var hasFetchedOnce = false

    @Volatile
    private var rateLimitUntil: Instant? = null

    suspend fun fetchUsageSnapshot(
        rawCredentialInput: String?,
        oauthBundleJson: String?,
        billingDayOfMonth: Int,
        importedStepsDbFile: File? = null,
        onRefreshedAccessToken: ((String) -> Unit)? = null,
        onRefreshedBundle: ((GoogleOAuthBundle) -> Unit)? = null,
        now: Instant = Instant.now()
    ): ServiceUsageSnapshot = withContext(Dispatchers.IO) {
        val parsedBundle = parseCredentialInput(oauthBundleJson ?: rawCredentialInput)
        val trimmedRaw = rawCredentialInput?.trim().orEmpty()
        var bundle = if (
            parsedBundle != null &&
            trimmedRaw.isNotEmpty() &&
            !trimmedRaw.startsWith("{") &&
            !trimmedRaw.startsWith("go-keyring-base64:")
        ) {
            parsedBundle.copy(accessToken = trimmedRaw)
        } else {
            parsedBundle
        }
        if (bundle == null || bundle.accessToken.isBlank()) {
            return@withContext ServiceUsageSnapshot(
                service = ServiceType.GOOGLE_AI,
                planName = "Google AI Pro Plan",
                status = GaugeStatus.UNKNOWN,
                lastUpdated = now,
                isAvailable = false
            )
        }

        val limitUntil = rateLimitUntil
        if (limitUntil != null && now.isBefore(limitUntil)) {
            return@withContext buildSnapshot(
                status = GaugeStatus.RATE_LIMITED,
                billingDayOfMonth = billingDayOfMonth,
                importedStepsDbFile = importedStepsDbFile,
                now = now,
                statusMessage = if (L10n.isKorean) "요청 한도 초과(429) · 잠시 후 재시도" else "Rate limited (429) · waiting"
            )
        }

        var result = fetchViaDirectRest(bundle.accessToken, now)

        if (result.unauthorized && !bundle.refreshToken.isNullOrBlank() && !bundle.clientId.isNullOrBlank()) {
            val refreshed = refreshAccessToken(bundle)
            if (refreshed != null) {
                val updatedBundle = bundle.copy(
                    accessToken = refreshed.accessToken,
                    refreshToken = refreshed.refreshToken ?: bundle.refreshToken
                )
                bundle = updatedBundle
                onRefreshedAccessToken?.invoke(refreshed.accessToken)
                onRefreshedBundle?.invoke(updatedBundle)
                result = fetchViaDirectRest(updatedBundle.accessToken, now)
            }
        }

        if (result.limits != null) {
            cachedLimits = result.limits
            hasFetchedOnce = true
            rateLimitUntil = null
            return@withContext buildSnapshot(
                status = GaugeStatus.NORMAL,
                billingDayOfMonth = billingDayOfMonth,
                importedStepsDbFile = importedStepsDbFile,
                now = now
            )
        }

        if (rateLimitUntil?.isAfter(now) == true) {
            return@withContext buildSnapshot(
                status = GaugeStatus.RATE_LIMITED,
                billingDayOfMonth = billingDayOfMonth,
                importedStepsDbFile = importedStepsDbFile,
                now = now,
                statusMessage = if (L10n.isKorean) "요청 한도 초과(429) · 잠시 후 재시도" else "Rate limited (429) · waiting"
            )
        }

        val hadMissingClientIdForRefresh = result.unauthorized &&
            !bundle.refreshToken.isNullOrBlank() &&
            bundle.clientId.isNullOrBlank()
        val diagnostic = if (result.lastErrorCode == 401 && hadMissingClientIdForRefresh) {
            if (L10n.isKorean) {
                "HTTP 401: 토큰이 만료되었고 자동 갱신용 client_id가 없습니다. 새 인증 JSON 또는 토큰을 가져오세요."
            } else {
                "HTTP 401: Token expired and JSON lacks client_id for auto-refresh. Import a fresh auth file."
            }
        } else {
            formatErrorDiagnostic(result.lastErrorCode, result.errorDetail, L10n.isKorean)
        }
        if (hasFetchedOnce || cachedLimits.hasAnyKnownQuota) {
            return@withContext buildSnapshot(
                status = GaugeStatus.WARNING,
                billingDayOfMonth = billingDayOfMonth,
                importedStepsDbFile = importedStepsDbFile,
                now = now,
                statusMessage = diagnostic
            )
        }

        val trend = readStepsTrendIfPresent(importedStepsDbFile, now)
        ServiceUsageSnapshot(
            service = ServiceType.GOOGLE_AI,
            planName = "Google AI Pro Plan",
            status = if (result.lastErrorCode == 401 || result.lastErrorCode == 403) GaugeStatus.ERROR else GaugeStatus.WARNING,
            lastUpdated = now,
            isAvailable = true,
            googleGroups = GoogleAIGroupLimits(),
            trendSummary = trend,
            statusMessage = diagnostic
        )
    }

    private data class RestFetchOutcome(
        val limits: GoogleAIGroupLimits? = null,
        val lastErrorCode: Int? = null,
        val errorDetail: String? = null
    ) {
        val unauthorized: Boolean get() = lastErrorCode == 401 || lastErrorCode == 403
    }

    private data class TokenRefreshResult(
        val accessToken: String,
        val refreshToken: String? = null
    )

    private fun fetchViaDirectRest(token: String, now: Instant): RestFetchOutcome {
        val projects = listOf("aicode-consumers", "default-cli-project", "")
        val jsonMedia = "application/json; charset=utf-8".toMediaType()
        var lastErrorCode: Int? = null
        var lastErrorDetail: String? = null

        for (url in endpoints) {
            for (project in projects) {
                val payload = if (project.isEmpty()) "{}" else JSONObject().put("project", project).toString()
                val req = Request.Builder()
                    .url(url)
                    .post(payload.toRequestBody(jsonMedia))
                    .header("Authorization", "Bearer $token")
                    .header("Content-Type", "application/json")
                    .header("Accept", "application/json")
                    .header("User-Agent", "antigravity/2.24.0 (aidev_client; os_type=android; arch=arm64)")
                    .build()

                try {
                    client.newCall(req).execute().use { resp ->
                        if (resp.code == 429) {
                            val retrySec = resp.header("Retry-After")?.toLongOrNull() ?: 300L
                            rateLimitUntil = now.plusSeconds(retrySec.coerceAtLeast(30L))
                            return RestFetchOutcome(null, 429, "RATE_LIMITED")
                        }
                        val body = resp.body?.string() ?: ""
                        if (resp.isSuccessful) {
                            val parsed = parseRestQuotaJson(body, cachedLimits, now, L10n.isKorean)
                            if (parsed != null) {
                                return RestFetchOutcome(parsed)
                            }
                        } else {
                            lastErrorCode = resp.code
                            lastErrorDetail = extractGoogleErrorReason(body) ?: lastErrorDetail
                        }
                    }
                } catch (e: Throwable) {
                    if (lastErrorCode == null) {
                        lastErrorDetail = e.message
                    }
                    continue
                }
            }
        }
        return RestFetchOutcome(null, lastErrorCode, lastErrorDetail)
    }

    private fun refreshAccessToken(bundle: GoogleOAuthBundle): TokenRefreshResult? {
        val refreshToken = bundle.refreshToken ?: return null
        val clientId = bundle.clientId ?: return null
        val formBuilder = FormBody.Builder()
            .add("grant_type", "refresh_token")
            .add("refresh_token", refreshToken)
            .add("client_id", clientId)
        if (!bundle.clientSecret.isNullOrBlank()) {
            formBuilder.add("client_secret", bundle.clientSecret)
        }
        val req = Request.Builder()
            .url(oauthTokenUrl)
            .post(formBuilder.build())
            .build()

        return try {
            client.newCall(req).execute().use { resp ->
                if (!resp.isSuccessful) return null
                val body = resp.body?.string() ?: return null
                val json = JSONObject(body)
                val access = json.optString("access_token", "").takeIf { it.isNotBlank() } ?: return null
                val rotatedRefresh = json.optString("refresh_token", "").takeIf { it.isNotBlank() }
                TokenRefreshResult(access, rotatedRefresh)
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun buildSnapshot(
        status: GaugeStatus,
        billingDayOfMonth: Int,
        importedStepsDbFile: File?,
        now: Instant,
        statusMessage: String? = null
    ): ServiceUsageSnapshot {
        val (dateStr, daysRem) = calculateNextBilling(
            dayOfMonth = billingDayOfMonth,
            now = now,
            zoneId = ZoneId.systemDefault(),
            isKorean = L10n.isKorean
        )
        val limits = cachedLimits.copy(
            nextBillingDateString = dateStr,
            daysUntilBilling = daysRem
        )
        val overallRemaining = limits.overallRemainingPercent
        val resolvedStatus = when {
            status == GaugeStatus.RATE_LIMITED -> GaugeStatus.RATE_LIMITED
            status == GaugeStatus.WARNING && statusMessage != null -> GaugeStatus.WARNING
            else -> when {
                overallRemaining <= 15.0 -> GaugeStatus.CRITICAL
                overallRemaining <= 35.0 -> GaugeStatus.WARNING
                else -> GaugeStatus.NORMAL
            }
        }

        return ServiceUsageSnapshot(
            service = ServiceType.GOOGLE_AI,
            planName = "Google AI Pro Plan",
            remainingPercent = overallRemaining,
            billingDateString = limits.nextBillingDateString,
            daysUntilBilling = limits.daysUntilBilling,
            status = resolvedStatus,
            lastUpdated = now,
            isAvailable = true,
            googleGroups = limits,
            trendSummary = readStepsTrendIfPresent(importedStepsDbFile, now),
            statusMessage = statusMessage
        )
    }

    fun importStepsDb(inputStream: InputStream, destDbFile: File): Boolean {
        val bytes = inputStream.readBytes()
        val sqliteHeader = "SQLite format 3".toByteArray(Charsets.US_ASCII)
        val isSqlite = bytes.size >= sqliteHeader.size &&
            bytes.sliceArray(0 until sqliteHeader.size).contentEquals(sqliteHeader)
        if (!isSqlite) return false
        destDbFile.writeBytes(bytes)
        return true
    }

    private fun readStepsTrendIfPresent(dbFile: File?, now: Instant): UsageTrendSummary {
        if (dbFile == null || !dbFile.exists()) {
            return UsageTrendSummary(metricUnit = UsageMetricUnit.STEPS, costAvailable = false)
        }
        return readLocalUsageTrendFromDb(dbFile, now)
    }

    fun readLocalUsageTrendFromDb(
        dbFile: File,
        now: Instant = Instant.now(),
        zoneId: ZoneId = ZoneId.systemDefault()
    ): UsageTrendSummary {
        if (!dbFile.exists()) return UsageTrendSummary(metricUnit = UsageMetricUnit.STEPS, costAvailable = false)
        var db: SQLiteDatabase? = null
        return try {
            db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
            val query = """
                SELECT
                    date(last_modified_time, 'localtime') as day,
                    sum(step_count) as steps
                FROM conversation_summaries
                WHERE datetime(last_modified_time) >= datetime('now', '-35 days')
                GROUP BY day
                ORDER BY day ASC
            """.trimIndent()
            val stepsByDate = HashMap<String, Int>()
            db.rawQuery(query, null).use { c ->
                while (c.moveToNext()) {
                    val day = c.getString(0) ?: continue
                    stepsByDate[day] = c.getLong(1).toInt()
                }
            }

            var recentLog = ""
            val logQuery = "SELECT title, step_count FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 1"
            db.rawQuery(logQuery, null).use { c ->
                if (c.moveToFirst()) {
                    val title = c.getString(0) ?: ""
                    val steps = c.getInt(1)
                    val cleanTitle = if (title.length > 20) "${title.take(18)}..." else title
                    recentLog = if (L10n.isKorean) {
                        "최근 세션: $cleanTitle ($steps steps)"
                    } else {
                        "Recent: $cleanTitle ($steps steps)"
                    }
                }
            }

            TrendBuilder.build30DaySummary(
                spendByDate = emptyMap(),
                tokensByDate = stepsByDate,
                zoneId = zoneId,
                now = now,
                metricUnit = UsageMetricUnit.STEPS,
                costAvailable = false,
                recentActivityLog = recentLog
            )
        } catch (_: Throwable) {
            UsageTrendSummary(metricUnit = UsageMetricUnit.STEPS, costAvailable = false)
        } finally {
            db?.close()
        }
    }

    companion object {
        private fun defaultHttpClient(): OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(6, TimeUnit.SECONDS)
            .readTimeout(6, TimeUnit.SECONDS)
            .build()

        fun parseCredentialInput(rawInput: String?): GoogleOAuthBundle? {
            var str = rawInput?.trim()?.removePrefix("\uFEFF").orEmpty()
            if (str.isEmpty()) return null

            if (str.startsWith("go-keyring-base64:")) {
                val encoded = str.removePrefix("go-keyring-base64:")
                str = try {
                    Base64.getDecoder().decode(encoded).toString(Charsets.UTF_8)
                        .trim()
                        .removePrefix("\uFEFF")
                } catch (_: Throwable) {
                    return null
                }
            }

            if (str.startsWith("{")) {
                return try {
                    val root = JSONObject(str)
                    val tokenObj = root.optJSONObject("token") ?: root
                    val access = tokenObj.optString("access_token", "")
                        .ifBlank { tokenObj.optString("accessToken", "") }
                        .ifBlank { root.optString("access_token", "") }
                        .ifBlank { root.optString("accessToken", "") }
                    if (access.isBlank()) return null
                    val refresh = tokenObj.optString("refresh_token", "")
                        .ifBlank { tokenObj.optString("refreshToken", "") }
                        .ifBlank { root.optString("refresh_token", "") }
                        .ifBlank { root.optString("refreshToken", "") }
                        .takeIf { it.isNotBlank() }
                    val clientObj = root.optJSONObject("installed")
                        ?: root.optJSONObject("web")
                        ?: root.optJSONObject("client")
                        ?: root
                    val clientId = clientObj.optString("client_id", "")
                        .ifBlank { clientObj.optString("clientId", "") }
                        .ifBlank { tokenObj.optString("client_id", "") }
                        .ifBlank { root.optString("client_id", "") }
                        .takeIf { it.isNotBlank() }
                    val clientSecret = clientObj.optString("client_secret", "")
                        .ifBlank { clientObj.optString("clientSecret", "") }
                        .ifBlank { tokenObj.optString("client_secret", "") }
                        .ifBlank { root.optString("client_secret", "") }
                        .takeIf { it.isNotBlank() }
                    val email = root.optString("email", "")
                        .ifBlank { tokenObj.optString("email", "") }
                        .takeIf { it.isNotBlank() }
                    GoogleOAuthBundle(
                        accessToken = access,
                        refreshToken = refresh,
                        clientId = clientId,
                        clientSecret = clientSecret,
                        email = email
                    )
                } catch (_: Throwable) {
                    null
                }
            }

            return GoogleOAuthBundle(accessToken = str)
        }

        fun extractGoogleErrorReason(rawBody: String?): String? {
            if (rawBody.isNullOrBlank()) return null
            return try {
                val root = JSONObject(rawBody)
                val err = root.optJSONObject("error") ?: root
                val details = err.optJSONArray("details")
                var detailReason = ""
                if (details != null) {
                    for (i in 0 until details.length()) {
                        val candidate = details.optJSONObject(i)?.optString("reason", "").orEmpty()
                        if (candidate.isNotBlank()) {
                            detailReason = candidate
                            break
                        }
                    }
                }
                val topStatus = err.optString("status", "")
                    .ifBlank { err.optString("reason", "") }
                when {
                    detailReason.isNotBlank() && topStatus.isNotBlank() && detailReason != topStatus ->
                        "$detailReason / $topStatus"
                    detailReason.isNotBlank() -> detailReason
                    topStatus.isNotBlank() -> topStatus
                    else -> err.optString("message", "").take(90).takeIf { it.isNotBlank() }
                }
            } catch (_: Throwable) {
                null
            }
        }

        fun formatErrorDiagnostic(code: Int?, detail: String?, isKorean: Boolean): String? {
            return when (code) {
                401 -> if (isKorean) {
                    "HTTP 401: 인증 토큰이 만료되었거나 유효하지 않습니다."
                } else {
                    "HTTP 401: OAuth token expired or invalid."
                }
                403 -> {
                    val suffix = detail?.let { " ($it)" } ?: ""
                    if (isKorean) {
                        "HTTP 403$suffix: Google 비공개 쿼터 API(cloudcode-pa) 권한이 없습니다."
                    } else {
                        "HTTP 403$suffix: Access denied by private Google quota API (cloudcode-pa)."
                    }
                }
                null -> detail?.let {
                    if (isKorean) "연결 확인 필요: $it" else "Connection issue: $it"
                }
                else -> "HTTP $code${detail?.let { " ($it)" } ?: ""}"
            }
        }

        fun calculateNextBilling(
            dayOfMonth: Int,
            now: Instant = Instant.now(),
            zoneId: ZoneId = ZoneId.systemDefault(),
            isKorean: Boolean = L10n.isKorean
        ): Pair<String, Int> {
            if (dayOfMonth !in 1..31) return "" to 0

            val zonedNow = now.atZone(zoneId)
            var targetYear = zonedNow.year
            var targetMonth = zonedNow.monthValue
            if (dayOfMonth < zonedNow.dayOfMonth) {
                targetMonth += 1
                if (targetMonth > 12) {
                    targetMonth = 1
                    targetYear += 1
                }
            }

            val maxDay = YearMonth.of(targetYear, targetMonth).lengthOfMonth()
            val clampedDay = minOf(dayOfMonth, maxDay)
            val targetInstant = LocalDate.of(targetYear, targetMonth, clampedDay)
                .atStartOfDay(zoneId)
                .toInstant()

            val diffSec = max(0L, Duration.between(now, targetInstant).seconds)
            val totalHours = (diffSec / 3600L).toInt()
            val days = totalHours / 24
            val hours = totalHours % 24

            val dateStr = if (days == 0) {
                if (hours == 0) {
                    if (isKorean) "오늘 리셋 (매월 ${dayOfMonth}일)" else "Resets today (${dayOfMonth}th)"
                } else {
                    if (isKorean) "${hours}시간 후 리셋 (매월 ${dayOfMonth}일)" else "Resets in ${hours}h (${dayOfMonth}th)"
                }
            } else {
                if (isKorean) "${days}일 ${hours}시간 후 리셋 (매월 ${dayOfMonth}일)" else "Resets in ${days}d ${hours}h (${dayOfMonth}th)"
            }
            return dateStr to days
        }

        fun parseRestQuotaJson(
            rawJson: String,
            baseLimits: GoogleAIGroupLimits = GoogleAIGroupLimits(),
            now: Instant = Instant.now(),
            isKorean: Boolean = L10n.isKorean
        ): GoogleAIGroupLimits? {
            return try {
                val root = JSONObject(rawJson)
                val groups = root.optJSONArray("groups") ?: return null
                if (groups.length() == 0) return null

                var result = baseLimits
                for (i in 0 until groups.length()) {
                    val g = groups.getJSONObject(i)
                    val gName = g.optString("displayName", "").lowercase()
                    val buckets = g.optJSONArray("buckets") ?: continue
                    for (j in 0 until buckets.length()) {
                        val b = buckets.getJSONObject(j)
                        val fraction = if (b.has("remainingFraction") && !b.isNull("remainingFraction")) {
                            b.getDouble("remainingFraction")
                        } else {
                            1.0
                        }
                        val pct = (fraction * 100.0).coerceIn(0.0, 100.0)
                        val resetTime = if (b.isNull("resetTime")) null else b.optString("resetTime", "")
                        val countdown = formatCountdown(resetTime, now, isKorean)
                        val bId = b.optString("bucketId", "").lowercase()

                        if (gName.contains("gemini models") || (!gName.contains("argon") && gName.contains("gemini"))) {
                            if (bId.contains("weekly")) {
                                result = result.copy(
                                    geminiWeeklyRemainingPercent = pct,
                                    geminiWeeklyResetString = countdown
                                )
                            } else if (bId.contains("5h") || bId.contains("five")) {
                                result = result.copy(
                                    geminiFiveHourRemainingPercent = pct,
                                    geminiFiveHourResetString = countdown
                                )
                            }
                        } else if (gName.contains("claude") || gName.contains("3p")) {
                            if (bId.contains("weekly")) {
                                result = result.copy(
                                    claudeWeeklyRemainingPercent = pct,
                                    claudeWeeklyResetString = countdown
                                )
                            } else if (bId.contains("5h") || bId.contains("five")) {
                                result = result.copy(
                                    claudeFiveHourRemainingPercent = pct,
                                    claudeFiveHourResetString = countdown
                                )
                            }
                        } else if (gName.contains("argon") || bId.contains("argon")) {
                            result = result.copy(
                                argonWeeklyRemainingPercent = pct,
                                argonWeeklyResetString = countdown
                            )
                        }
                    }
                }
                result
            } catch (_: Throwable) {
                null
            }
        }

        private fun formatCountdown(resetIso: String?, now: Instant, isKorean: Boolean): String {
            val target = ISO8601Parser.parseInstant(resetIso) ?: return L10n.quotaAvailable
            val diffSec = max(0L, Duration.between(now, target).seconds)
            val totalHours = diffSec / 3600L
            val mins = (diffSec % 3600L) / 60L
            return if (totalHours >= 24L) {
                val days = totalHours / 24L
                val remHours = totalHours % 24L
                if (isKorean) "${days}일 ${remHours}시간 후 리셋" else "Resets in ${days}d ${remHours}h"
            } else {
                if (isKorean) "${totalHours}시간 ${mins}분 후 리셋" else "Resets in ${totalHours}h ${mins}m"
            }
        }
    }
}
