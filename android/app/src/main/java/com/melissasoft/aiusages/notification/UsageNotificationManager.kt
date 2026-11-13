package com.melissasoft.aiusages.notification

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.IconCompat
import com.melissasoft.aiusages.MainActivity
import com.melissasoft.aiusages.R
import com.melissasoft.aiusages.model.GaugeStatus
import com.melissasoft.aiusages.storage.AppSettingsRepository
import com.melissasoft.aiusages.storage.WidgetCacheState
import com.melissasoft.aiusages.storage.WidgetGaugeCacheEntry
import com.melissasoft.aiusages.util.L10n
import com.melissasoft.aiusages.widget.BatteryGaugeRenderer

/**
 * Manages the persistent Android Status Bar gauge indicator (`smallIcon`) and the
 * sleek ongoing compact/expanded notification shade dashboard card.
 */
object UsageNotificationManager {
    const val CHANNEL_ID = "aiusages_live_status_v1"
    const val NOTIFICATION_ID = 4102
    const val ACTION_NOTIFICATION_REFRESH = "com.melissasoft.aiusages.ACTION_NOTIFICATION_REFRESH"

    data class CompactSummaryText(
        val primaryLine: String,
        val secondaryLine: String,
        val expandedLines: String
    )

    data class ShadeChip(
        val text: String,
        val percent: Double,
        val status: GaugeStatus
    )

    data class ShadeProviderRow(
        val name: String,
        val detail: String,
        val valueText: String,
        val percent: Double,
        val status: GaugeStatus
    )

    data class ShadeNotificationModel(
        val chips: List<ShadeChip>,
        val compactSecondaryLine: String,
        val expandedTitle: String,
        val expandedSubtitle: String,
        val rows: List<ShadeProviderRow>,
        val emptyText: String?,
        val subTextTime: String?
    )

    fun hasNotificationPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return false
        }
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    fun ensureChannel(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        // IMPORTANCE_DEFAULT with sound=null and vibration=false ensures the smallIcon remains
        // visible in the top Status Bar even when "Hide silent notifications" is enabled on OEMs.
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.notif_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = context.getString(R.string.notif_channel_desc)
            setSound(null, null)
            enableVibration(false)
            enableLights(false)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    fun formatCompactSummary(
        cache: WidgetCacheState?,
        noActiveFallback: String,
        isKorean: Boolean = L10n.isKorean
    ): CompactSummaryText {
        val entries = cache?.entries.orEmpty()
        if (entries.isEmpty()) {
            val secondary = if (isKorean) {
                "탭하여 프로바이더를 연결하세요"
            } else {
                "Tap to connect AI providers"
            }
            return CompactSummaryText(
                primaryLine = noActiveFallback,
                secondaryLine = secondary,
                expandedLines = noActiveFallback
            )
        }

        val chips = entries.mapNotNull { entry ->
            entry.compactChip.takeIf { it.isNotBlank() } ?: entry.summaryLine.takeIf { it.isNotBlank() }
        }
        val primary = chips.joinToString(" · ").ifBlank { noActiveFallback }

        val firstReset = entries.firstNotNullOfOrNull { it.resetHint.takeIf { h -> h.isNotBlank() } }
        val updated = cache?.updatedAtText?.takeIf { it.isNotBlank() }
        val secondaryParts = buildList {
            if (firstReset != null) add(firstReset)
            if (updated != null) {
                add(if (isKorean) "$updated 업데이트" else "Updated $updated")
            }
        }
        val secondary = secondaryParts.joinToString(" · ")
        val expanded = entries.joinToString("\n") { it.summaryLine }

        return CompactSummaryText(
            primaryLine = primary,
            secondaryLine = secondary,
            expandedLines = expanded
        )
    }

    fun buildShadeModel(
        cache: WidgetCacheState?,
        noActiveFallback: String,
        isKorean: Boolean = L10n.isKorean
    ): ShadeNotificationModel {
        val entries = cache?.entries.orEmpty().take(3)
        val updated = cache?.updatedAtText?.takeIf { it.isNotBlank() && it != "--:--" }
        if (entries.isEmpty()) {
            val secondary = if (isKorean) {
                "탭하여 프로바이더를 연결하세요"
            } else {
                "Tap to connect AI providers"
            }
            return ShadeNotificationModel(
                chips = emptyList(),
                compactSecondaryLine = secondary,
                expandedTitle = noActiveFallback,
                expandedSubtitle = secondary,
                rows = emptyList(),
                emptyText = noActiveFallback,
                subTextTime = updated
            )
        }

        val chips = entries.map { e ->
            ShadeChip(
                text = e.compactChip.takeIf { it.isNotBlank() } ?: e.summaryLine.take(14),
                percent = e.percent,
                status = e.status
            )
        }

        val firstReset = entries.firstNotNullOfOrNull { it.resetHint.takeIf { h -> h.isNotBlank() } }
        val compactSecondary = buildList {
            if (firstReset != null) add(firstReset)
            if (updated != null) add(if (isKorean) "$updated 갱신" else "Updated $updated")
        }.joinToString(" · ")

        val hasError = entries.any { it.status == GaugeStatus.ERROR }
        val hasWarning = entries.any { it.status == GaugeStatus.CRITICAL || it.status == GaugeStatus.WARNING }
        val stateBadge = when {
            hasError -> if (isKorean) "연결 확인 필요" else "Check Auth"
            hasWarning -> if (isKorean) "여유 주의" else "Low Quota"
            else -> if (isKorean) "정상" else "Healthy"
        }
        val expandedTitle = if (isKorean) {
            "활성 서비스 ${entries.size}개 · $stateBadge"
        } else {
            "${entries.size} Active · $stateBadge"
        }
        val expandedSubtitle = when {
            firstReset != null && updated != null -> "$firstReset · $updated"
            firstReset != null -> firstReset
            updated != null -> if (isKorean) "$updated 기준 · 탭하여 앱 열기" else "Updated $updated · Tap to open"
            else -> if (isKorean) "탭하여 상세 사용량 보기" else "Tap to view details"
        }

        val rows = entries.map { toProviderRow(it, isKorean) }

        return ShadeNotificationModel(
            chips = chips,
            compactSecondaryLine = compactSecondary,
            expandedTitle = expandedTitle,
            expandedSubtitle = expandedSubtitle,
            rows = rows,
            emptyText = null,
            subTextTime = updated
        )
    }

    private fun toProviderRow(entry: WidgetGaugeCacheEntry, isKorean: Boolean): ShadeProviderRow {
        val fallbackName = entry.summaryLine.substringBefore(":").substringBefore(" (").trim()
        val name = entry.providerTitle.takeIf { it.isNotBlank() } ?: fallbackName.ifBlank { "AI" }
        val valueText = entry.valueText.takeIf { it.isNotBlank() } ?: "${entry.percent.toInt()}%"
        val detail = entry.detailText.takeIf { it.isNotBlank() }
            ?: entry.resetHint.takeIf { it.isNotBlank() }
            ?: (if (isKorean) "사용량 추적 중" else "Tracking usage")
        return ShadeProviderRow(
            name = name,
            detail = detail,
            valueText = valueText,
            percent = entry.percent,
            status = entry.status
        )
    }

    fun updateOrShow(context: Context) {
        val appContext = context.applicationContext
        val settings = AppSettingsRepository(appContext)
        if (!settings.statusBarIndicatorEnabled || !hasNotificationPermission(appContext)) {
            return
        }
        ensureChannel(appContext)

        val cache = settings.readWidgetCache()
        val density = appContext.resources.displayMetrics.density.coerceIn(2f, 4f)
        val isNight = (appContext.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

        val gaugeItems = cache?.entries?.map {
            BatteryGaugeRenderer.GaugeItem(it.percent, it.status)
        } ?: emptyList()

        val daysUntilReset = cache?.daysUntilReset ?: 999
        val statusIconBitmap = BatteryGaugeRenderer.renderStatusBarIconBitmap(
            items = gaugeItems,
            daysUntilReset = daysUntilReset,
            density = 3f
        )
        val badgeBitmap = BatteryGaugeRenderer.renderNotificationBadgeBitmap(
            items = gaugeItems,
            daysUntilReset = daysUntilReset,
            density = density,
            isNight = isNight
        )

        val noActive = appContext.getString(R.string.notif_no_active)
        val summary = formatCompactSummary(cache, noActive, L10n.isKorean)
        val shade = buildShadeModel(cache, noActive, L10n.isKorean)

        val openIntent = Intent(appContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPending = PendingIntent.getActivity(
            appContext,
            100,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val refreshIntent = Intent(appContext, UsageNotificationActionReceiver::class.java).apply {
            action = ACTION_NOTIFICATION_REFRESH
        }
        val refreshPending = PendingIntent.getBroadcast(
            appContext,
            101,
            refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val chipSlots = listOf(
            Triple(R.id.notif_chip_1, R.id.notif_chip_dot_1, R.id.notif_chip_text_1),
            Triple(R.id.notif_chip_2, R.id.notif_chip_dot_2, R.id.notif_chip_text_2),
            Triple(R.id.notif_chip_3, R.id.notif_chip_dot_3, R.id.notif_chip_text_3)
        )

        val compactViews = RemoteViews(appContext.packageName, R.layout.notification_gauge_compact).apply {
            setImageViewBitmap(R.id.notif_gauge_image, badgeBitmap)
            setOnClickPendingIntent(R.id.notif_refresh_btn, refreshPending)

            if (shade.emptyText != null) {
                setViewVisibility(R.id.notif_chips_row, View.GONE)
                setViewVisibility(R.id.notif_compact_empty, View.VISIBLE)
                setTextViewText(R.id.notif_compact_empty, shade.emptyText)
            } else {
                setViewVisibility(R.id.notif_chips_row, View.VISIBLE)
                setViewVisibility(R.id.notif_compact_empty, View.GONE)
                chipSlots.forEachIndexed { idx, (containerId, dotId, textId) ->
                    val chip = shade.chips.getOrNull(idx)
                    if (chip != null) {
                        val color = BatteryGaugeRenderer.resolveColorArgb(chip.percent, chip.status)
                        setViewVisibility(containerId, View.VISIBLE)
                        setImageViewBitmap(dotId, BatteryGaugeRenderer.renderColorDotBitmap(color, 6f, density))
                        setTextViewText(textId, chip.text)
                    } else {
                        setViewVisibility(containerId, View.GONE)
                    }
                }
            }

            if (shade.compactSecondaryLine.isNotBlank()) {
                setViewVisibility(R.id.notif_compact_secondary, View.VISIBLE)
                setTextViewText(R.id.notif_compact_secondary, shade.compactSecondaryLine)
            } else {
                setViewVisibility(R.id.notif_compact_secondary, View.GONE)
            }
        }

        val expandedSlots = listOf(
            listOf(
                R.id.notif_exp_row_1,
                R.id.notif_exp_accent_1,
                R.id.notif_exp_name_1,
                R.id.notif_exp_detail_1,
                R.id.notif_exp_value_1,
                R.id.notif_exp_bar_1
            ),
            listOf(
                R.id.notif_exp_row_2,
                R.id.notif_exp_accent_2,
                R.id.notif_exp_name_2,
                R.id.notif_exp_detail_2,
                R.id.notif_exp_value_2,
                R.id.notif_exp_bar_2
            ),
            listOf(
                R.id.notif_exp_row_3,
                R.id.notif_exp_accent_3,
                R.id.notif_exp_name_3,
                R.id.notif_exp_detail_3,
                R.id.notif_exp_value_3,
                R.id.notif_exp_bar_3
            )
        )

        val expandedViews = RemoteViews(appContext.packageName, R.layout.notification_gauge_expanded).apply {
            setImageViewBitmap(R.id.notif_expanded_gauge_image, badgeBitmap)
            setTextViewText(R.id.notif_expanded_title, shade.expandedTitle)
            setTextViewText(R.id.notif_expanded_subtitle, shade.expandedSubtitle)
            setOnClickPendingIntent(R.id.notif_expanded_refresh_btn, refreshPending)

            if (shade.emptyText != null) {
                setViewVisibility(R.id.notif_expanded_empty, View.VISIBLE)
                setTextViewText(R.id.notif_expanded_empty, shade.expandedSubtitle)
            } else {
                setViewVisibility(R.id.notif_expanded_empty, View.GONE)
            }

            expandedSlots.forEachIndexed { idx, ids ->
                val row = shade.rows.getOrNull(idx)
                if (row != null) {
                    val color = BatteryGaugeRenderer.resolveColorArgb(row.percent, row.status)
                    setViewVisibility(ids[0], View.VISIBLE)
                    setImageViewBitmap(ids[1], BatteryGaugeRenderer.renderVerticalAccentBitmap(color, 4f, 22f, density))
                    setTextViewText(ids[2], row.name)
                    setTextViewText(ids[3], row.detail)
                    setTextViewText(ids[4], row.valueText)
                    setImageViewBitmap(
                        ids[5],
                        BatteryGaugeRenderer.renderMiniProgressBarBitmap(
                            percent = row.percent,
                            status = row.status,
                            widthDp = 56f,
                            heightDp = 5f,
                            density = density,
                            isNight = isNight
                        )
                    )
                } else {
                    setViewVisibility(ids[0], View.GONE)
                }
            }
        }

        val builder = NotificationCompat.Builder(appContext, CHANNEL_ID)
            .setSmallIcon(IconCompat.createWithBitmap(statusIconBitmap))
            .setContentTitle(appContext.getString(R.string.app_name))
            .setContentText(summary.primaryLine)
            .setContentIntent(openPending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setAutoCancel(false)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(compactViews)
            .setCustomBigContentView(expandedViews)

        if (shade.subTextTime != null) {
            builder.setSubText(shade.subTextTime)
        }

        runCatching {
            NotificationManagerCompat.from(appContext).notify(NOTIFICATION_ID, builder.build())
        }
    }

    fun dismiss(context: Context) {
        runCatching {
            NotificationManagerCompat.from(context.applicationContext).cancel(NOTIFICATION_ID)
        }
    }
}
