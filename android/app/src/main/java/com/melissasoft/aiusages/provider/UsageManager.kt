package com.melissasoft.aiusages.provider

import android.content.Context
import android.net.Uri
import com.melissasoft.aiusages.model.GaugeStatus
import com.melissasoft.aiusages.model.ProviderCategory
import com.melissasoft.aiusages.model.ProviderDescriptor
import com.melissasoft.aiusages.model.ServiceType
import com.melissasoft.aiusages.model.ServiceUsageSnapshot
import com.melissasoft.aiusages.model.TokenCostSnapshot
import com.melissasoft.aiusages.model.UsageTrendSummary
import com.melissasoft.aiusages.storage.AppSettingsRepository
import com.melissasoft.aiusages.storage.WidgetCacheState
import com.melissasoft.aiusages.storage.WidgetGaugeCacheEntry
import com.melissasoft.aiusages.util.L10n
import com.melissasoft.aiusages.widget.BatteryGaugeRenderer
import com.melissasoft.aiusages.widget.BatteryGaugeWidgetProvider
import com.melissasoft.aiusages.worker.UsageRefreshWorker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

data class UsageUiState(
    val openCodeSnapshot: ServiceUsageSnapshot = ServiceUsageSnapshot(service = ServiceType.OPEN_CODE),
    val googleAISnapshot: ServiceUsageSnapshot = ServiceUsageSnapshot(service = ServiceType.GOOGLE_AI),
    val openRouterSnapshot: TokenCostSnapshot = TokenCostSnapshot(),
    val registeredProviders: List<ProviderDescriptor> = emptyList(),
    val enabledProviderIds: Set<String> = emptySet(),
    val providerOrder: List<String> = emptyList(),
    val refreshIntervalSeconds: Long = 300L,
    val googleBillingDayOfMonth: Int = 0,
    val selectedMetricKeys: Map<String, String> = emptyMap(),
    val isRefreshing: Boolean = false,
    val lastRefreshedAt: Instant = Instant.now(),
    val gaugeItems: List<BatteryGaugeRenderer.GaugeItem> = emptyList(),
    val gaugeTooltips: List<String> = emptyList(),
    val nearestBillingDays: Int = 999,
    val updateState: UpdateState = UpdateState.IDLE,
    val pendingReleaseVersion: String? = null,
    val pendingReleaseUrl: String? = null,
    val pendingReleaseApkUrl: String? = null,
    val statusBannerMessage: String? = null
)

class UsageManager(context: Context) {
    private val appContext = context.applicationContext
    val settings = AppSettingsRepository(appContext)
    private val openCodeProvider = OpenCodeProvider()
    private val googleAIProvider = GoogleAIProvider()
    private val openRouterProvider = OpenRouterProvider()
    private val updaterRepository = UpdaterRepository()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var timerJob: Job? = null
    private val refreshMutex = Mutex()

    private val _uiState = MutableStateFlow(UsageUiState())
    val uiState: StateFlow<UsageUiState> = _uiState.asStateFlow()

    init {
        syncSettingsToState()
        startForegroundTicker()
        UsageRefreshWorker.schedulePeriodic(appContext, settings.refreshIntervalSeconds)
    }

    fun hasKey(providerId: String): Boolean {
        if (providerId == "google_ai") {
            return settings.keyStore.hasKey("google_ai") ||
                settings.keyStore.readGoogleOAuthJson() != null
        }
        return settings.keyStore.hasKey(providerId)
    }

    fun isProviderDetected(providerId: String): Boolean {
        return when (providerId) {
            "opencode" -> hasKey("opencode") || settings.importedOpenCodeDbFile.exists()
            "google_ai" -> hasKey("google_ai") || settings.importedGoogleStepsDbFile.exists()
            else -> hasKey(providerId)
        }
    }

    fun syncSettingsToState() {
        val enabled = settings.enabledProviderIds
        val order = settings.providerOrder
        val descriptors = listOf(
            ProviderDescriptor("codex", "Codex", ProviderCategory.TOKEN_AND_COST, isProviderDetected("codex"), settings.isProviderEnabled("codex")),
            ProviderDescriptor("claude", "Claude", ProviderCategory.QUOTA, isProviderDetected("claude"), settings.isProviderEnabled("claude")),
            ProviderDescriptor("cursor", "Cursor", ProviderCategory.QUOTA, isProviderDetected("cursor"), settings.isProviderEnabled("cursor")),
            ProviderDescriptor("google_ai", "Google AI", ProviderCategory.QUOTA, isProviderDetected("google_ai"), settings.isProviderEnabled("google_ai")),
            ProviderDescriptor("opencode", "OpenCode Go", ProviderCategory.QUOTA, isProviderDetected("opencode"), settings.isProviderEnabled("opencode")),
            ProviderDescriptor("openrouter", "OpenRouter", ProviderCategory.TOKEN_AND_COST, isProviderDetected("openrouter"), settings.isProviderEnabled("openrouter")),
            ProviderDescriptor("copilot", "Copilot", ProviderCategory.QUOTA, isProviderDetected("copilot"), settings.isProviderEnabled("copilot")),
            ProviderDescriptor("perplexity", "Perplexity", ProviderCategory.TOKEN_AND_COST, isProviderDetected("perplexity"), settings.isProviderEnabled("perplexity")),
            ProviderDescriptor("deepseek", "DeepSeek", ProviderCategory.TOKEN_AND_COST, isProviderDetected("deepseek"), settings.isProviderEnabled("deepseek"))
        )
        val metricKeys = mapOf(
            "opencode" to settings.selectedMetricKey("opencode"),
            "google_ai" to settings.selectedMetricKey("google_ai")
        )
        _uiState.update { state ->
            state.copy(
                registeredProviders = descriptors,
                enabledProviderIds = enabled,
                providerOrder = order,
                refreshIntervalSeconds = settings.refreshIntervalSeconds,
                googleBillingDayOfMonth = settings.googleBillingDayOfMonth,
                selectedMetricKeys = metricKeys
            )
        }
        recomputeGaugesAndWidget()
    }

    fun startForegroundTicker() {
        timerJob?.cancel()
        val intervalMs = settings.refreshIntervalSeconds * 1000L
        timerJob = scope.launch {
            while (isActive) {
                delay(intervalMs)
                refreshAll()
            }
        }
    }

    fun setRefreshIntervalSeconds(seconds: Long) {
        settings.refreshIntervalSeconds = seconds
        syncSettingsToState()
        startForegroundTicker()
        UsageRefreshWorker.schedulePeriodic(appContext, seconds)
    }

    fun toggleProvider(id: String) {
        val currently = settings.isProviderEnabled(id)
        settings.setProviderEnabled(id, !currently)
        syncSettingsToState()
        scope.launch { refreshAll() }
    }

    fun moveProviderUp(id: String) {
        settings.moveProviderUp(id)
        syncSettingsToState()
    }

    fun moveProviderDown(id: String) {
        settings.moveProviderDown(id)
        syncSettingsToState()
    }

    fun setSelectedMetricKey(providerId: String, key: String) {
        settings.setSelectedMetricKey(providerId, key)
        syncSettingsToState()
    }

    fun setGoogleBillingDay(day: Int) {
        settings.googleBillingDayOfMonth = day
        syncSettingsToState()
        scope.launch { refreshAll() }
    }

    fun saveProviderKey(providerId: String, rawInput: String) {
        val cleaned = rawInput.trim()
        if (cleaned.isEmpty()) return
        if (providerId == "google_ai") {
            if (cleaned.startsWith("{") || cleaned.startsWith("go-keyring-base64:")) {
                val bundle = GoogleAIProvider.parseCredentialInput(cleaned)
                if (bundle != null) {
                    settings.keyStore.saveGoogleOAuthJson(cleaned)
                    settings.saveProviderKey("google_ai", bundle.accessToken)
                } else {
                    settings.keyStore.saveGoogleOAuthJson(null)
                    settings.saveProviderKey("google_ai", cleaned)
                }
            } else {
                settings.keyStore.saveGoogleOAuthJson(null)
                settings.saveProviderKey("google_ai", cleaned)
            }
        } else {
            settings.saveProviderKey(providerId, cleaned)
        }
        syncSettingsToState()
        scope.launch { refreshAll() }
    }

    fun deleteProviderKey(providerId: String) {
        settings.deleteProviderKey(providerId)
        if (providerId == "opencode" && settings.importedOpenCodeDbFile.exists()) {
            settings.importedOpenCodeDbFile.delete()
        }
        if (providerId == "google_ai" && settings.importedGoogleStepsDbFile.exists()) {
            settings.importedGoogleStepsDbFile.delete()
        }
        syncSettingsToState()
        scope.launch { refreshAll() }
    }

    fun importOpenCodeFile(uri: Uri) {
        scope.launch(Dispatchers.IO) {
            val token = appContext.contentResolver.openInputStream(uri)?.use { stream ->
                openCodeProvider.importFromFile(stream, settings.importedOpenCodeDbFile)
            }
            if (!token.isNullOrBlank()) {
                settings.saveProviderKey("opencode", token)
                _uiState.update {
                    it.copy(
                        statusBannerMessage = if (L10n.isKorean) {
                            "OpenCode Go 인증 및 사용 내역을 가져왔습니다."
                        } else {
                            "Imported OpenCode Go credentials & history."
                        }
                    )
                }
            } else {
                _uiState.update {
                    it.copy(
                        statusBannerMessage = if (L10n.isKorean) {
                            "파일에서 OpenCode Go 토큰을 찾지 못했습니다."
                        } else {
                            "No OpenCode Go credential found in file."
                        }
                    )
                }
            }
            withContext(Dispatchers.Main.immediate) {
                syncSettingsToState()
                refreshAll()
            }
        }
    }

    fun importGoogleStepsDb(uri: Uri) {
        scope.launch(Dispatchers.IO) {
            val ok = appContext.contentResolver.openInputStream(uri)?.use { stream ->
                googleAIProvider.importStepsDb(stream, settings.importedGoogleStepsDbFile)
            } ?: false
            _uiState.update {
                it.copy(
                    statusBannerMessage = if (ok) {
                        if (L10n.isKorean) "Google AI 스텝 기록 DB를 가져왔습니다." else "Imported Google AI activity DB."
                    } else {
                        if (L10n.isKorean) "유효한 SQLite DB 파일이 아닙니다." else "Invalid SQLite DB file."
                    }
                )
            }
            withContext(Dispatchers.Main.immediate) {
                syncSettingsToState()
                refreshAll()
            }
        }
    }

    fun clearBanner() {
        _uiState.update { it.copy(statusBannerMessage = null) }
    }

    suspend fun refreshAll() {
        if (!refreshMutex.tryLock()) return
        try {
            _uiState.update { it.copy(isRefreshing = true) }

            val now = Instant.now()
            val ocEnabled = settings.isProviderEnabled("opencode")
            val gEnabled = settings.isProviderEnabled("google_ai")
            val orEnabled = settings.isProviderEnabled("openrouter")

            val current = _uiState.value
            val (ocResult, gResult, orResult) = coroutineScope {
                val ocDef = async {
                    if (ocEnabled) {
                        openCodeProvider.fetchUsageSnapshot(
                            token = settings.keyStore.readKey("opencode"),
                            importedDbFile = settings.importedOpenCodeDbFile,
                            now = now
                        )
                    } else current.openCodeSnapshot
                }
                val gDef = async {
                    if (gEnabled) {
                        googleAIProvider.fetchUsageSnapshot(
                            rawCredentialInput = settings.keyStore.readKey("google_ai"),
                            oauthBundleJson = settings.keyStore.readGoogleOAuthJson(),
                            billingDayOfMonth = settings.googleBillingDayOfMonth,
                            importedStepsDbFile = settings.importedGoogleStepsDbFile,
                            onRefreshedAccessToken = { newToken ->
                                settings.keyStore.saveKey("google_ai", newToken)
                            },
                            now = now
                        )
                    } else current.googleAISnapshot
                }
                val orDef = async {
                    if (orEnabled) {
                        openRouterProvider.fetchSnapshot(
                            apiKey = settings.keyStore.readKey("openrouter"),
                            now = now
                        )
                    } else current.openRouterSnapshot
                }
                Triple(ocDef.await(), gDef.await(), orDef.await())
            }

            _uiState.update {
                it.copy(
                    openCodeSnapshot = ocResult,
                    googleAISnapshot = gResult,
                    openRouterSnapshot = orResult,
                    isRefreshing = false,
                    lastRefreshedAt = now
                )
            }
            syncSettingsToState()
        } finally {
            _uiState.update { it.copy(isRefreshing = false) }
            refreshMutex.unlock()
        }
    }

    fun checkForUpdates(silent: Boolean = false) {
        if (_uiState.value.updateState == UpdateState.CHECKING) return
        _uiState.update { it.copy(updateState = UpdateState.CHECKING) }
        scope.launch {
            val release = updaterRepository.fetchLatestRelease()
            if (release != null) {
                if (UpdaterRepository.isNewer(release.version)) {
                    _uiState.update {
                        it.copy(
                            updateState = UpdateState.UPDATE_AVAILABLE,
                            pendingReleaseVersion = release.version,
                            pendingReleaseUrl = release.htmlUrl,
                            pendingReleaseApkUrl = release.apkDownloadUrl
                        )
                    }
                } else {
                    _uiState.update {
                        it.copy(
                            updateState = UpdateState.UP_TO_DATE,
                            statusBannerMessage = if (silent) null else {
                                if (L10n.isKorean) "최신 버전을 사용 중입니다." else "You're up to date."
                            }
                        )
                    }
                    delay(4000)
                    _uiState.update {
                        if (it.updateState == UpdateState.UP_TO_DATE) it.copy(updateState = UpdateState.IDLE) else it
                    }
                }
            } else {
                _uiState.update {
                    it.copy(
                        updateState = UpdateState.FAILED,
                        statusBannerMessage = if (silent) null else {
                            if (L10n.isKorean) "업데이트 확인 실패" else "Update check failed."
                        }
                    )
                }
                delay(4000)
                _uiState.update {
                    if (it.updateState == UpdateState.FAILED) it.copy(updateState = UpdateState.IDLE) else it
                }
            }
        }
    }

    private fun recomputeGaugesAndWidget() {
        val state = _uiState.value
        val gaugeItems = mutableListOf<BatteryGaugeRenderer.GaugeItem>()
        val widgetEntries = mutableListOf<WidgetGaugeCacheEntry>()
        val tooltips = mutableListOf<String>()
        var nearestDays = 999

        for (id in state.providerOrder) {
            if (!settings.isProviderEnabled(id)) continue
            when (id) {
                "opencode" -> {
                    val oc = state.openCodeSnapshot
                    if (!oc.isAvailable) continue
                    val key = settings.selectedMetricKey("opencode")
                    val (pct, label, resetStr) = when (key) {
                        "opencode_weekly" -> Triple(
                            oc.openCodeWindows.weeklyRemainingPercent,
                            if (L10n.isKorean) "주간" else "Weekly",
                            oc.openCodeWindows.weeklyResetString
                        )
                        "opencode_monthly" -> Triple(
                            oc.openCodeWindows.monthlyRemainingPercent,
                            if (L10n.isKorean) "월간" else "Monthly",
                            oc.openCodeWindows.monthlyResetString
                        )
                        else -> Triple(
                            oc.openCodeWindows.fiveHourRemainingPercent,
                            if (L10n.isKorean) "5시간" else "5h",
                            oc.openCodeWindows.fiveHourResetString
                        )
                    }
                    val status = if (oc.status == GaugeStatus.RATE_LIMITED) {
                        GaugeStatus.RATE_LIMITED
                    } else {
                        pctToStatus(pct)
                    }
                    val line = "OpenCode Go ($label): ${pct.toInt()}% ${L10n.remaining}"
                    gaugeItems.add(BatteryGaugeRenderer.GaugeItem(pct, status))
                    widgetEntries.add(WidgetGaugeCacheEntry(pct, status, line))
                    tooltips.add("$line ($resetStr)")
                    nearestDays = minOf(nearestDays, oc.daysUntilBilling)
                }
                "google_ai" -> {
                    val g = state.googleAISnapshot
                    if (!g.isAvailable) continue
                    val key = settings.selectedMetricKey("google_ai")
                    val groups = g.googleGroups
                    val (pct, label, resetStr) = when (key) {
                        "google_claude_5h" -> Triple(
                            groups.claudeFiveHourRemainingPercent ?: groups.overallRemainingPercent,
                            if (L10n.isKorean) "5시간(Claude)" else "5h (Claude)",
                            groups.claudeFiveHourResetString
                        )
                        "google_gemini_weekly" -> Triple(
                            groups.geminiWeeklyRemainingPercent ?: groups.overallRemainingPercent,
                            if (L10n.isKorean) "주간(Gemini)" else "Weekly (Gemini)",
                            groups.geminiWeeklyResetString
                        )
                        "google_claude_weekly" -> Triple(
                            groups.claudeWeeklyRemainingPercent ?: groups.overallRemainingPercent,
                            if (L10n.isKorean) "주간(Claude)" else "Weekly (Claude)",
                            groups.claudeWeeklyResetString
                        )
                        "google_argon_weekly" -> Triple(
                            groups.argonWeeklyRemainingPercent ?: groups.overallRemainingPercent,
                            if (L10n.isKorean) "주간(Argon)" else "Weekly (Argon)",
                            groups.argonWeeklyResetString
                        )
                        "google_monthly" -> Triple(
                            if (groups.overallRemainingPercent > 0.0) groups.overallRemainingPercent else g.remainingPercent,
                            if (L10n.isKorean) "월간" else "Monthly",
                            groups.nextBillingDateString.ifBlank { "-" }
                        )
                        else -> Triple(
                            groups.geminiFiveHourRemainingPercent ?: groups.overallRemainingPercent,
                            if (L10n.isKorean) "5시간(Gemini)" else "5h (Gemini)",
                            groups.geminiFiveHourResetString
                        )
                    }
                    val status = if (g.status == GaugeStatus.RATE_LIMITED) {
                        GaugeStatus.RATE_LIMITED
                    } else {
                        pctToStatus(pct)
                    }
                    val line = "Google AI ($label): ${pct.toInt()}% ${L10n.remaining}"
                    gaugeItems.add(BatteryGaugeRenderer.GaugeItem(pct, status))
                    widgetEntries.add(WidgetGaugeCacheEntry(pct, status, line))
                    tooltips.add("$line ($resetStr)")
                    if (settings.googleBillingDayOfMonth > 0) {
                        nearestDays = minOf(nearestDays, g.daysUntilBilling)
                    }
                }
                "openrouter" -> {
                    val or = state.openRouterSnapshot
                    if (!or.isConnected) continue
                    val bal = or.balanceUSD
                    val pct = ((bal / 10.0) * 100.0).coerceIn(0.0, 100.0)
                    val line = "OpenRouter: $${String.format(Locale.US, "%.2f", bal)}"
                    gaugeItems.add(BatteryGaugeRenderer.GaugeItem(pct, or.status))
                    widgetEntries.add(WidgetGaugeCacheEntry(pct, or.status, line))
                    tooltips.add(line)
                }
            }
        }

        val timeText = DateTimeFormatter.ofPattern("HH:mm")
            .withZone(ZoneId.systemDefault())
            .format(state.lastRefreshedAt)
        settings.saveWidgetCache(
            WidgetCacheState(
                entries = widgetEntries.take(3),
                daysUntilReset = nearestDays,
                updatedAtText = timeText
            )
        )
        BatteryGaugeWidgetProvider.updateAllWidgets(appContext)

        _uiState.update {
            it.copy(
                gaugeItems = gaugeItems,
                gaugeTooltips = tooltips,
                nearestBillingDays = nearestDays
            )
        }
    }

    private fun pctToStatus(pct: Double): GaugeStatus = when {
        pct <= 15.0 -> GaugeStatus.CRITICAL
        pct <= 35.0 -> GaugeStatus.WARNING
        else -> GaugeStatus.NORMAL
    }
}
