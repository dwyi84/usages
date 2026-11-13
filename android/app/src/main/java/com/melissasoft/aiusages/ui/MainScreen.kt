package com.melissasoft.aiusages.ui

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.melissasoft.aiusages.BuildConfig
import com.melissasoft.aiusages.model.ProviderKeySpec
import com.melissasoft.aiusages.model.UsageTrendSummary
import com.melissasoft.aiusages.provider.UpdateState
import com.melissasoft.aiusages.provider.UsageManager
import com.melissasoft.aiusages.ui.components.BatteryGaugeStrip
import com.melissasoft.aiusages.ui.components.DetailedTrendDialog
import com.melissasoft.aiusages.ui.components.GoogleAISectionCard
import com.melissasoft.aiusages.ui.components.KeyOnlyProviderCard
import com.melissasoft.aiusages.ui.components.OpenCodeSectionCard
import com.melissasoft.aiusages.ui.components.OpenRouterSectionCard
import com.melissasoft.aiusages.ui.components.ProviderManagementSection
import com.melissasoft.aiusages.ui.theme.DS
import com.melissasoft.aiusages.ui.theme.GlassTile
import com.melissasoft.aiusages.ui.theme.SoftDivider
import com.melissasoft.aiusages.util.L10n
import kotlinx.coroutines.launch
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun MainScreen(usageManager: UsageManager) {
    val state by usageManager.uiState.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }

    val activeOrder = remember(state.providerOrder, state.enabledProviderIds) {
        state.providerOrder.filter { state.enabledProviderIds.contains(it) }
    }
    var showProviderSettings by remember { mutableStateOf(activeOrder.isEmpty()) }
    var trendDialogData by remember { mutableStateOf<Pair<String, UsageTrendSummary>?>(null) }
    var showUpdateDialog by remember { mutableStateOf(false) }

    val openCodeFileLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) usageManager.importOpenCodeFile(uri)
    }

    val googleDbLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) usageManager.importGoogleStepsDb(uri)
    }

    LaunchedEffect(state.statusBannerMessage) {
        val msg = state.statusBannerMessage ?: return@LaunchedEffect
        snackbarHostState.showSnackbar(msg)
        usageManager.clearBanner()
    }

    val timeFmt = remember { DateTimeFormatter.ofPattern("HH:mm:ss").withZone(ZoneId.systemDefault()) }

    val infiniteTransition = rememberInfiniteTransition(label = "refresh_spin")
    val spinAngle by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "spin"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(DS.windowGradient())
            .statusBarsPadding()
            .navigationBarsPadding()
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // MARK: - Top Header Bar
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = DS.SpacingLg, vertical = 10.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Filled.BarChart,
                        contentDescription = null,
                        tint = DS.AccentBlue,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(Modifier.width(7.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = L10n.appTitle,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = DS.textPrimary(),
                            maxLines = 1
                        )
                        Text(
                            text = "v${BuildConfig.VERSION_NAME} · ${timeFmt.format(state.lastRefreshedAt)}",
                            fontSize = 10.5.sp,
                            color = DS.textSecondary(),
                            maxLines = 1
                        )
                    }

                    // Signature 4-Segment Battery Gauge Summary Strip
                    GlassTile(cornerRadius = DS.RadiusPill) {
                        Box(modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)) {
                            BatteryGaugeStrip(
                                items = state.gaugeItems,
                                daysUntilReset = state.nearestBillingDays
                            )
                        }
                    }

                    Spacer(Modifier.width(6.dp))

                    IconButton(
                        onClick = { scope.launch { usageManager.refreshAll() } },
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Refresh,
                            contentDescription = L10n.refreshTooltip,
                            tint = DS.textSecondary(),
                            modifier = Modifier
                                .size(18.dp)
                                .rotate(if (state.isRefreshing) spinAngle else 0f)
                        )
                    }
                }

                // Refresh Interval Selector + Update Check Row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    IntervalSegmentedControl(
                        selectedSeconds = state.refreshIntervalSeconds,
                        onSelect = { usageManager.setRefreshIntervalSeconds(it) },
                        modifier = Modifier.weight(1f)
                    )

                    if (state.updateState == UpdateState.UPDATE_AVAILABLE && state.pendingReleaseVersion != null) {
                        Button(
                            onClick = { showUpdateDialog = true },
                            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                            modifier = Modifier.height(30.dp)
                        ) {
                            Text("v${state.pendingReleaseVersion} Update", fontSize = 10.5.sp)
                        }
                    } else {
                        OutlinedButton(
                            onClick = { usageManager.checkForUpdates(silent = false) },
                            enabled = state.updateState != UpdateState.CHECKING,
                            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                            modifier = Modifier.height(30.dp)
                        ) {
                            Text(
                                text = if (state.updateState == UpdateState.CHECKING) L10n.checking else L10n.checkForUpdates,
                                fontSize = 10.5.sp,
                                maxLines = 1
                            )
                        }
                    }
                }
            }

            SoftDivider()

            // MARK: - Scrollable Content Body
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = DS.SpacingLg, vertical = DS.SpacingMd),
                verticalArrangement = Arrangement.spacedBy(DS.SpacingMd)
            ) {
                if (activeOrder.isEmpty()) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            text = L10n.noActiveProviders,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                            color = DS.textSecondary()
                        )
                        Text(
                            text = L10n.noActiveProvidersHint,
                            fontSize = 11.sp,
                            color = DS.textTertiary()
                        )
                    }
                } else {
                    for (id in activeOrder) {
                        val canMoveUp = state.providerOrder.firstOrNull() != id
                        val canMoveDown = state.providerOrder.lastOrNull() != id
                        when (id) {
                            "opencode" -> OpenCodeSectionCard(
                                snapshot = state.openCodeSnapshot,
                                selectedMetricKey = state.selectedMetricKeys["opencode"] ?: "opencode_5h",
                                hasKey = usageManager.hasKey("opencode"),
                                canMoveUp = canMoveUp,
                                canMoveDown = canMoveDown,
                                onMoveUp = { usageManager.moveProviderUp("opencode") },
                                onMoveDown = { usageManager.moveProviderDown("opencode") },
                                onSelectMetric = { usageManager.setSelectedMetricKey("opencode", it) },
                                onSaveKey = { usageManager.saveProviderKey("opencode", it) },
                                onDeleteKey = { usageManager.deleteProviderKey("opencode") },
                                onImportFile = { openCodeFileLauncher.launch(arrayOf("*/*")) },
                                onOpenTrendDetail = { title, summary -> trendDialogData = title to summary }
                            )

                            "google_ai" -> GoogleAISectionCard(
                                snapshot = state.googleAISnapshot,
                                selectedMetricKey = state.selectedMetricKeys["google_ai"] ?: "google_gemini_5h",
                                billingDayOfMonth = state.googleBillingDayOfMonth,
                                hasKey = usageManager.hasKey("google_ai"),
                                canMoveUp = canMoveUp,
                                canMoveDown = canMoveDown,
                                onMoveUp = { usageManager.moveProviderUp("google_ai") },
                                onMoveDown = { usageManager.moveProviderDown("google_ai") },
                                onSelectMetric = { usageManager.setSelectedMetricKey("google_ai", it) },
                                onSaveBillingDay = { usageManager.setGoogleBillingDay(it) },
                                onSaveKey = { usageManager.saveProviderKey("google_ai", it) },
                                onDeleteKey = { usageManager.deleteProviderKey("google_ai") },
                                onImportStepsDb = { googleDbLauncher.launch(arrayOf("*/*")) },
                                onOpenTrendDetail = { title, summary -> trendDialogData = title to summary }
                            )

                            "openrouter" -> OpenRouterSectionCard(
                                snapshot = state.openRouterSnapshot,
                                hasKey = usageManager.hasKey("openrouter"),
                                canMoveUp = canMoveUp,
                                canMoveDown = canMoveDown,
                                onMoveUp = { usageManager.moveProviderUp("openrouter") },
                                onMoveDown = { usageManager.moveProviderDown("openrouter") },
                                onSaveKey = { usageManager.saveProviderKey("openrouter", it) },
                                onDeleteKey = { usageManager.deleteProviderKey("openrouter") },
                                onOpenTrendDetail = { title, summary -> trendDialogData = title to summary }
                            )

                            "cursor" -> KeyOnlyProviderCard(
                                providerId = "cursor",
                                providerName = "Cursor",
                                promptHint = if (L10n.isKorean) "Cursor 토큰 입력 (선택사항)" else "Cursor Token (Optional)",
                                placeholder = "token...",
                                hasKey = usageManager.hasKey("cursor"),
                                canMoveUp = canMoveUp,
                                canMoveDown = canMoveDown,
                                onMoveUp = { usageManager.moveProviderUp("cursor") },
                                onMoveDown = { usageManager.moveProviderDown("cursor") },
                                onSaveKey = { usageManager.saveProviderKey("cursor", it) },
                                onDeleteKey = { usageManager.deleteProviderKey("cursor") },
                                onOpenTrendDetail = { title, summary -> trendDialogData = title to summary }
                            )

                            else -> ProviderKeySpec.genericSpecs[id]?.let { spec ->
                                KeyOnlyProviderCard(
                                    providerId = spec.id,
                                    providerName = spec.name,
                                    promptHint = if (L10n.isKorean) {
                                        "API 키 입력 (${spec.envKeyName})"
                                    } else {
                                        "Enter API Key (${spec.envKeyName})"
                                    },
                                    placeholder = "${spec.keyPrefix}...",
                                    hasKey = usageManager.hasKey(spec.id),
                                    canMoveUp = canMoveUp,
                                    canMoveDown = canMoveDown,
                                    onMoveUp = { usageManager.moveProviderUp(spec.id) },
                                    onMoveDown = { usageManager.moveProviderDown(spec.id) },
                                    onSaveKey = { usageManager.saveProviderKey(spec.id, it) },
                                    onDeleteKey = { usageManager.deleteProviderKey(spec.id) },
                                    onOpenTrendDetail = { title, summary -> trendDialogData = title to summary }
                                )
                            }
                        }
                    }
                }

                SoftDivider(alpha = 0.6f)

                ProviderManagementSection(
                    providers = state.registeredProviders,
                    expanded = showProviderSettings,
                    onToggleExpanded = { showProviderSettings = !showProviderSettings },
                    onToggleProvider = { usageManager.toggleProvider(it) }
                )
            }

            SoftDivider()

            // MARK: - Footer
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = DS.SpacingLg, vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = if (L10n.isKorean) "홈 화면 위젯으로 게이지 고정 가능" else "Add Home Screen Widget for live gauges",
                        fontSize = 10.sp,
                        color = DS.textSecondary(),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f)
                    )
                    Spacer(Modifier.width(8.dp))
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(DS.RadiusPill))
                            .background(DS.CoffeeYellow)
                            .clickable {
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://buymeacoffee.com/dwyi84d"))
                                context.startActivity(intent)
                            }
                            .padding(horizontal = 10.dp, vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("☕", fontSize = 11.sp)
                        Spacer(Modifier.width(4.dp))
                        Text(
                            text = L10n.buyMeACoffee,
                            fontSize = 10.5.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color.Black
                        )
                    }
                }
                Text(
                    text = "Crafted by MelissaSoft",
                    fontSize = 9.5.sp,
                    fontWeight = FontWeight.Medium,
                    color = DS.textTertiary()
                )
            }
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter)
        )
    }

    trendDialogData?.let { (title, summary) ->
        DetailedTrendDialog(
            title = title,
            summary = summary,
            onDismiss = { trendDialogData = null }
        )
    }

    if (showUpdateDialog && state.pendingReleaseVersion != null) {
        val ver = state.pendingReleaseVersion!!
        val targetUrl = state.pendingReleaseApkUrl ?: state.pendingReleaseUrl
        AlertDialog(
            onDismissRequest = { showUpdateDialog = false },
            title = {
                Text(
                    if (L10n.isKorean) "v$ver 버전 업데이트 가능" else "Update to v$ver?"
                )
            },
            text = {
                Text(
                    if (L10n.isKorean) {
                        "AI Usages v$ver 을 사용할 수 있습니다 (현재 버전: v${BuildConfig.VERSION_NAME}). GitHub Releases 페이지에서 최신 빌드를 확인할 수 있습니다."
                    } else {
                        "AI Usages v$ver is available (current: v${BuildConfig.VERSION_NAME}). Open GitHub Releases to download."
                    }
                )
            },
            confirmButton = {
                Button(onClick = {
                    showUpdateDialog = false
                    if (!targetUrl.isNullOrBlank()) {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(targetUrl)))
                    }
                }) {
                    Text(L10n.updateNow)
                }
            },
            dismissButton = {
                TextButton(onClick = { showUpdateDialog = false }) {
                    Text(L10n.later)
                }
            }
        )
    }
}

@Composable
private fun IntervalSegmentedControl(
    selectedSeconds: Long,
    onSelect: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    val options = listOf(
        60L to L10n.min1,
        180L to L10n.min3,
        300L to L10n.min5,
        900L to L10n.min15
    )
    GlassTile(
        cornerRadius = DS.RadiusPill,
        modifier = modifier.height(30.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(2.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            for ((sec, label) in options) {
                val active = selectedSeconds == sec
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxSize()
                        .clip(RoundedCornerShape(6.dp))
                        .background(if (active) DS.AccentBlue else Color.Transparent)
                        .border(
                            0.5.dp,
                            if (active) DS.AccentBlue else Color.Transparent,
                            RoundedCornerShape(6.dp)
                        )
                        .clickable { onSelect(sec) },
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = label,
                        fontSize = 10.5.sp,
                        fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                        color = if (active) Color.White else DS.textSecondary(),
                        maxLines = 1
                    )
                }
            }
        }
    }
}
