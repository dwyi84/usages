package com.melissasoft.aiusages

import com.melissasoft.aiusages.model.GaugeStatus
import com.melissasoft.aiusages.model.GoogleAIGroupLimits
import com.melissasoft.aiusages.provider.GoogleAIProvider
import com.melissasoft.aiusages.provider.OpenCodeProvider
import com.melissasoft.aiusages.provider.OpenRouterProvider
import com.melissasoft.aiusages.provider.UpdaterRepository
import com.melissasoft.aiusages.util.ISO8601Parser
import com.melissasoft.aiusages.widget.BatteryGaugeRenderer
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Base64

class UsageCorrectnessTests {

    // MARK: - ISO-8601 parsing

    @Test
    fun parsesFractionalSecondTimestamps() {
        val instant = ISO8601Parser.parseInstant("2026-11-09T00:00:00.000Z")
        assertNotNull(instant)
        assertEquals(1_794_182_400L, instant!!.epochSecond)
    }

    @Test
    fun parsesPlainTimestamps() {
        assertNotNull(ISO8601Parser.parseInstant("2026-11-07T04:57:11Z"))
        assertNotNull(ISO8601Parser.parseInstant("2026-11-07T04:57:11+00:00"))
    }

    @Test
    fun parsesHighPrecisionTimestamps() {
        assertNotNull(ISO8601Parser.parseInstant("2026-11-03T17:57:37.123456Z"))
        assertNotNull(ISO8601Parser.parseInstant("2026-11-03T17:57:37.123456789Z"))
    }

    @Test
    fun rejectsInvalidTimestamps() {
        assertNull(ISO8601Parser.parseInstant(null))
        assertNull(ISO8601Parser.parseInstant(""))
        assertNull(ISO8601Parser.parseInstant("not-a-date"))
    }

    // MARK: - OpenCode credentials & API

    @Test
    fun readsOpenCodeAPIKeyCredential() {
        val json = """{"type":"key","key":"oc_sk_example"}"""
        assertEquals("oc_sk_example", OpenCodeProvider.tokenFromCredentialJson(json))
    }

    @Test
    fun readsOpenCodeOAuthCredential() {
        val json = """{"type":"oauth","access":"oauth-access-token","refresh":"refresh-token"}"""
        assertEquals("oauth-access-token", OpenCodeProvider.tokenFromCredentialJson(json))
    }

    @Test
    fun prefersAccessTokenWhenBothPresent() {
        val json = """{"access":"oauth-access-token","key":"oc_sk_example"}"""
        assertEquals("oauth-access-token", OpenCodeProvider.tokenFromCredentialJson(json))
    }

    @Test
    fun rejectsMalformedCredentials() {
        assertNull(OpenCodeProvider.tokenFromCredentialJson("not json"))
        assertNull(OpenCodeProvider.tokenFromCredentialJson("""{"key":""}"""))
        assertNull(OpenCodeProvider.tokenFromCredentialJson("""{"type":"key"}"""))
    }

    @Test
    fun readsNestedTokenObjectAndAuthFile() {
        val nested = """{"tokens":{"access_token":"nested-token"}}"""
        assertEquals("nested-token", OpenCodeProvider.tokenFromCredentialJson(nested))

        val authJson = """{"opencode-go":{"type":"key","key":"oc_sk_from_auth"}}"""
        assertEquals("oc_sk_from_auth", OpenCodeProvider.tokenFromAuthFileJson(authJson))
    }

    @Test
    fun openCodeRemoteApiParsesAndHandlesRateLimit() = runTest {
        val server = MockWebServer()
        server.start()
        try {
            val baseNow = Instant.parse("2026-11-10T00:00:00Z")
            server.enqueue(
                MockResponse()
                    .setResponseCode(200)
                    .setBody(
                        """
                        {
                          "usage": {
                            "rolling": { "percent": 12.0, "resetsAt": "2026-11-10T04:00:00.000Z" },
                            "weekly": { "percent": 40.0, "resetsAt": "2026-11-16T00:00:00.000Z" },
                            "monthly": { "percent": 70.0, "resetsAt": "2026-11-12T00:00:00.000Z" }
                          }
                        }
                        """.trimIndent()
                    )
            )
            server.enqueue(MockResponse().setResponseCode(429).setHeader("Retry-After", "120"))

            val provider = OpenCodeProvider(
                client = OkHttpClient(),
                usageUrl = server.url("/zen/go/v1/usage").toString()
            )

            val snap1 = provider.fetchUsageSnapshot(token = "oc_sk_test", now = baseNow)
            assertTrue(snap1.isAvailable)
            assertEquals(88.0, snap1.openCodeWindows.fiveHourRemainingPercent, 0.001)
            assertEquals(60.0, snap1.openCodeWindows.weeklyRemainingPercent, 0.001)
            assertEquals(30.0, snap1.openCodeWindows.monthlyRemainingPercent, 0.001)
            assertEquals(GaugeStatus.WARNING, snap1.status)
            assertEquals(2, snap1.daysUntilBilling)

            // 429 must keep stale snapshot and flag RATE_LIMITED
            val snap2 = provider.fetchUsageSnapshot(token = "oc_sk_test", now = baseNow.plusSeconds(30))
            assertEquals(GaugeStatus.RATE_LIMITED, snap2.status)
            assertEquals(30.0, snap2.openCodeWindows.monthlyRemainingPercent, 0.001)
        } finally {
            server.shutdown()
        }
    }

    // MARK: - Google billing date & quota

    private val kstZone = ZoneId.of("Asia/Seoul")

    private fun makeInstant(year: Int, month: Int, day: Int, hour: Int = 12): Instant =
        ZonedDateTime.of(year, month, day, hour, 0, 0, 0, kstZone).toInstant()

    @Test
    fun clampsBillingDayToShorterMonth() {
        val now = makeInstant(2026, 11, 3)
        val (_, days) = GoogleAIProvider.calculateNextBilling(31, now, kstZone, isKorean = false)
        assertEquals(26, days)
    }

    @Test
    fun clampsBillingDayFebruary() {
        val now = makeInstant(2026, 2, 10)
        val (_, days) = GoogleAIProvider.calculateNextBilling(31, now, kstZone, isKorean = false)
        assertEquals(17, days)
    }

    @Test
    fun rollsPassedBillingDayIntoNextYear() {
        val now = makeInstant(2026, 12, 20)
        val (_, days) = GoogleAIProvider.calculateNextBilling(5, now, kstZone, isKorean = false)
        assertEquals(15, days)
    }

    @Test
    fun billingDayTodayShowsZeroDays() {
        val now = makeInstant(2026, 11, 3, 18)
        val (_, days) = GoogleAIProvider.calculateNextBilling(3, now, kstZone, isKorean = false)
        assertEquals(0, days)
    }

    @Test
    fun unsetBillingDayReturnsEmpty() {
        val (str, days) = GoogleAIProvider.calculateNextBilling(0)
        assertEquals("", str)
        assertEquals(0, days)
    }

    @Test
    fun overallQuotaIgnoresMissingGroupsAndFallsBackToFiveHour() {
        val weekly = GoogleAIGroupLimits(
            geminiWeeklyRemainingPercent = 79.33,
            claudeWeeklyRemainingPercent = 100.0
        )
        assertEquals(79.33, weekly.overallRemainingPercent, 0.001)

        val fiveHour = GoogleAIGroupLimits(
            geminiFiveHourRemainingPercent = 42.0,
            claudeFiveHourRemainingPercent = 73.0
        )
        assertEquals(42.0, fiveHour.overallRemainingPercent, 0.001)
        assertEquals(0.0, GoogleAIGroupLimits().overallRemainingPercent, 0.001)
    }

    @Test
    fun googleCredentialParsingSupportsGoKeyringBase64AndJson() {
        val rawJson = """{"token":{"access_token":"ya29.abc","refresh_token":"1//ref"},"client_id":"cid"}"""
        val encoded = "go-keyring-base64:" + Base64.getEncoder().encodeToString(rawJson.toByteArray())
        val parsed = GoogleAIProvider.parseCredentialInput(encoded)
        assertNotNull(parsed)
        assertEquals("ya29.abc", parsed!!.accessToken)
        assertEquals("1//ref", parsed.refreshToken)
        assertEquals("cid", parsed.clientId)
    }

    @Test
    fun googleRestQuotaAndOAuthRefreshWork() = runTest {
        val server = MockWebServer()
        server.start()
        try {
            server.enqueue(MockResponse().setResponseCode(401))
            server.enqueue(MockResponse().setResponseCode(401))
            server.enqueue(MockResponse().setResponseCode(401))
            server.enqueue(
                MockResponse()
                    .setResponseCode(200)
                    .setBody("""{"access_token":"ya29.fresh"}""")
            )
            server.enqueue(
                MockResponse()
                    .setResponseCode(200)
                    .setBody(
                        """
                        {
                          "groups": [
                            {
                              "displayName": "Gemini Models",
                              "buckets": [
                                { "bucketId": "gemini_5h", "remainingFraction": 0.82, "resetTime": "2026-11-10T03:00:00Z" },
                                { "bucketId": "gemini_weekly", "remainingFraction": 0.65, "resetTime": "2026-11-15T00:00:00Z" }
                              ]
                            },
                            {
                              "displayName": "Claude & GPT",
                              "buckets": [
                                { "bucketId": "claude_weekly", "remainingFraction": 1.0 }
                              ]
                            }
                          ]
                        }
                        """.trimIndent()
                    )
            )

            var refreshedSaved: String? = null
            val provider = GoogleAIProvider(
                client = OkHttpClient(),
                endpoints = listOf(server.url("/v1internal:retrieveUserQuotaSummary").toString()),
                oauthTokenUrl = server.url("/token").toString()
            )
            val bundleJson = """{"token":{"access_token":"ya29.expired","refresh_token":"1//r"},"client_id":"cid"}"""
            val snap = provider.fetchUsageSnapshot(
                rawCredentialInput = "ya29.expired",
                oauthBundleJson = bundleJson,
                billingDayOfMonth = 17,
                onRefreshedAccessToken = { refreshedSaved = it },
                now = Instant.parse("2026-11-10T00:00:00Z")
            )

            assertEquals("ya29.fresh", refreshedSaved)
            assertTrue(snap.isAvailable)
            assertEquals(82.0, snap.googleGroups.geminiFiveHourRemainingPercent!!, 0.01)
            assertEquals(65.0, snap.googleGroups.geminiWeeklyRemainingPercent!!, 0.01)
            assertEquals(100.0, snap.googleGroups.claudeWeeklyRemainingPercent!!, 0.01)
            assertNull(snap.googleGroups.argonWeeklyRemainingPercent)
            assertEquals(65.0, snap.remainingPercent, 0.01)
        } finally {
            server.shutdown()
        }
    }

    @Test
    fun googleUsesUpdatedRawAccessTokenOverStaleBundleToken() = runTest {
        val server = MockWebServer()
        server.start()
        try {
            server.enqueue(
                MockResponse()
                    .setResponseCode(200)
                    .setBody(
                        """
                        {
                          "groups": [
                            {
                              "displayName": "Gemini Models",
                              "buckets": [
                                { "bucketId": "gemini_5h", "remainingFraction": 0.90 }
                              ]
                            }
                          ]
                        }
                        """.trimIndent()
                    )
            )
            val provider = GoogleAIProvider(
                client = OkHttpClient(),
                endpoints = listOf(server.url("/v1internal:retrieveUserQuotaSummary").toString())
            )
            val staleBundle = """{"token":{"access_token":"ya29.stale","refresh_token":"1//r"},"client_id":"cid"}"""
            provider.fetchUsageSnapshot(
                rawCredentialInput = "ya29.newer_saved",
                oauthBundleJson = staleBundle,
                billingDayOfMonth = 1,
                now = Instant.parse("2026-11-10T00:00:00Z")
            )
            val recorded = server.takeRequest()
            assertEquals("Bearer ya29.newer_saved", recorded.getHeader("Authorization"))
        } finally {
            server.shutdown()
        }
    }

    // MARK: - OpenRouter API & UTC Trend

    @Test
    fun openRouterFetchesCreditsKeyAndActivity() = runTest {
        val server = MockWebServer()
        server.start()
        try {
            val baseNow = Instant.parse("2026-11-13T10:00:00Z")
            server.dispatcher = object : okhttp3.mockwebserver.Dispatcher() {
                override fun dispatch(request: okhttp3.mockwebserver.RecordedRequest): MockResponse {
                    return when (request.path) {
                        "/api/v1/credits" -> MockResponse().setBody("""{"data":{"total_credits":25.0,"total_usage":10.5}}""")
                        "/api/v1/key" -> MockResponse().setBody("""{"data":{"usage":10.5,"usage_daily":1.25,"usage_weekly":4.0,"usage_monthly":9.0,"prompt_tokens":1200,"completion_tokens":300}}""")
                        "/api/v1/activity" -> MockResponse().setBody("""{"data":[{"date":"2026-11-13","usage":1.25,"prompt_tokens":800,"completion_tokens":200},{"date":"2026-11-12","usage":2.0,"prompt_tokens":400,"completion_tokens":100}]}""")
                        else -> MockResponse().setResponseCode(404)
                    }
                }
            }

            val provider = OpenRouterProvider(
                client = OkHttpClient(),
                baseUrl = server.url("/api/v1").toString().removeSuffix("/")
            )
            val snap = provider.fetchSnapshot("sk-or-test", now = baseNow)
            assertTrue(snap.isConnected)
            assertEquals(14.5, snap.balanceUSD, 0.001)
            assertEquals(1.25, snap.todaySpendUSD, 0.001)
            assertEquals(9.0, snap.monthSpendUSD, 0.001)
            assertEquals(1500, snap.totalTokens)
            assertEquals(30, snap.trendSummary.dailyPoints.size)
            assertEquals(1000, snap.trendSummary.todayTokens)
            assertEquals(500, snap.trendSummary.yesterdayTokens)
            assertEquals(GaugeStatus.NORMAL, snap.status)
        } finally {
            server.shutdown()
        }
    }

    // MARK: - Updater & Battery Gauge Renderer

    @Test
    fun updaterParsesReleaseAndComparesSemver() {
        val json = """
            {
              "tag_name": "v0.3.0",
              "html_url": "https://github.com/dwyi84/usages/releases/tag/v0.3.0",
              "assets": [
                { "browser_download_url": "https://example.com/AIUsages-0.3.0.zip" },
                { "browser_download_url": "https://example.com/AIUsages-0.3.0.apk" }
              ]
            }
        """.trimIndent()
        val info = UpdaterRepository.parseReleaseJson(json)
        assertNotNull(info)
        assertEquals("0.3.0", info!!.version)
        assertEquals("https://example.com/AIUsages-0.3.0.apk", info.apkDownloadUrl)
        assertTrue(UpdaterRepository.isNewer("0.3.0", "0.2.7"))
        assertFalse(UpdaterRepository.isNewer("0.2.7", "0.2.7"))
        assertFalse(UpdaterRepository.isNewer("0.2.6", "0.2.7"))
    }

    @Test
    fun batteryGaugeSegmentAndColorThresholds() {
        assertEquals(0, BatteryGaugeRenderer.activeSegmentCount(0.0))
        assertEquals(1, BatteryGaugeRenderer.activeSegmentCount(1.0))
        assertEquals(1, BatteryGaugeRenderer.activeSegmentCount(25.0))
        assertEquals(2, BatteryGaugeRenderer.activeSegmentCount(26.0))
        assertEquals(3, BatteryGaugeRenderer.activeSegmentCount(75.0))
        assertEquals(4, BatteryGaugeRenderer.activeSegmentCount(100.0))

        assertEquals(0xFFFF453A.toInt(), BatteryGaugeRenderer.resolveColorArgb(15.0, GaugeStatus.CRITICAL))
        assertEquals(0xFFFF9E0D.toInt(), BatteryGaugeRenderer.resolveColorArgb(35.0, GaugeStatus.WARNING))
        assertEquals(0xFF2ED159.toInt(), BatteryGaugeRenderer.resolveColorArgb(80.0, GaugeStatus.NORMAL))
        assertEquals(0xFFAF52DE.toInt(), BatteryGaugeRenderer.resolveColorArgb(90.0, GaugeStatus.RATE_LIMITED))
    }
}
