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
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.IconCompat
import com.melissasoft.aiusages.MainActivity
import com.melissasoft.aiusages.R
import com.melissasoft.aiusages.storage.AppSettingsRepository
import com.melissasoft.aiusages.storage.WidgetCacheState
import com.melissasoft.aiusages.util.L10n
import com.melissasoft.aiusages.widget.BatteryGaugeRenderer

/**
 * Manages the persistent Android Status Bar gauge indicator (`smallIcon`) and the
 * ongoing compact notification drawer card ("축약 형태 상시 알림").
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

    fun updateOrShow(context: Context) {
        val appContext = context.applicationContext
        val settings = AppSettingsRepository(appContext)
        if (!settings.statusBarIndicatorEnabled || !hasNotificationPermission(appContext)) {
            return
        }
        ensureChannel(appContext)

        val cache = settings.readWidgetCache()
        val density = appContext.resources.displayMetrics.density.coerceAtLeast(2f)
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
        val shadeGaugeBitmap = BatteryGaugeRenderer.renderDynamicBarsBitmap(
            items = gaugeItems,
            daysUntilReset = daysUntilReset,
            density = density,
            lightInactiveTint = isNight
        )

        val summary = formatCompactSummary(
            cache = cache,
            noActiveFallback = appContext.getString(R.string.notif_no_active),
            isKorean = L10n.isKorean
        )

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

        val compactViews = RemoteViews(appContext.packageName, R.layout.notification_gauge_compact).apply {
            setImageViewBitmap(R.id.notif_gauge_image, shadeGaugeBitmap)
            setTextViewText(R.id.notif_compact_primary, summary.primaryLine)
            setTextViewText(R.id.notif_compact_secondary, summary.secondaryLine)
            setOnClickPendingIntent(R.id.notif_refresh_btn, refreshPending)
        }

        val updatedLabel = cache?.updatedAtText?.takeIf { it.isNotBlank() }
        val expandedSub = if (updatedLabel != null) {
            if (L10n.isKorean) "$updatedLabel 기준" else "As of $updatedLabel"
        } else {
            summary.secondaryLine
        }
        val expandedViews = RemoteViews(appContext.packageName, R.layout.notification_gauge_expanded).apply {
            setImageViewBitmap(R.id.notif_expanded_gauge_image, shadeGaugeBitmap)
            setTextViewText(R.id.notif_expanded_title, appContext.getString(R.string.app_name))
            setTextViewText(R.id.notif_expanded_subtitle, expandedSub)
            setTextViewText(R.id.notif_expanded_lines, summary.expandedLines)
            setOnClickPendingIntent(R.id.notif_expanded_refresh_btn, refreshPending)
        }

        val notification = NotificationCompat.Builder(appContext, CHANNEL_ID)
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
            .build()

        runCatching {
            NotificationManagerCompat.from(appContext).notify(NOTIFICATION_ID, notification)
        }
    }

    fun dismiss(context: Context) {
        runCatching {
            NotificationManagerCompat.from(context.applicationContext).cancel(NOTIFICATION_ID)
        }
    }
}
