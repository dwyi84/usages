package com.melissasoft.aiusages.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.melissasoft.aiusages.MainActivity
import com.melissasoft.aiusages.R
import com.melissasoft.aiusages.storage.AppSettingsRepository
import com.melissasoft.aiusages.worker.UsageRefreshWorker

class BatteryGaugeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
        enqueueImmediateRefresh(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_WIDGET_REFRESH) {
            enqueueImmediateRefresh(context)
        }
    }

    companion object {
        const val ACTION_WIDGET_REFRESH = "com.melissasoft.aiusages.ACTION_WIDGET_REFRESH"

        fun enqueueImmediateRefresh(context: Context) {
            val req = OneTimeWorkRequestBuilder<UsageRefreshWorker>().build()
            WorkManager.getInstance(context.applicationContext).enqueue(req)
        }

        fun updateAllWidgets(context: Context) {
            val appContext = context.applicationContext
            val manager = AppWidgetManager.getInstance(appContext)
            val ids = manager.getAppWidgetIds(
                ComponentName(appContext, BatteryGaugeWidgetProvider::class.java)
            )
            for (id in ids) {
                updateWidget(appContext, manager, id)
            }
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_battery_gauge)
            val cache = AppSettingsRepository(context).readWidgetCache()
            val density = context.resources.displayMetrics.density

            val gaugeItems = cache?.entries?.map {
                BatteryGaugeRenderer.GaugeItem(it.percent, it.status)
            } ?: emptyList()

            val bitmap = BatteryGaugeRenderer.renderDynamicBarsBitmap(
                items = gaugeItems,
                daysUntilReset = cache?.daysUntilReset ?: 999,
                density = density,
                lightInactiveTint = true
            )
            views.setImageViewBitmap(R.id.widget_gauge_image, bitmap)
            views.setTextViewText(R.id.widget_updated, cache?.updatedAtText ?: "")

            val summaryText = if (cache == null || cache.entries.isEmpty()) {
                context.getString(R.string.widget_no_active)
            } else {
                cache.entries.joinToString("\n") { it.summaryLine }
            }
            views.setTextViewText(R.id.widget_summary, summaryText)

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openPending = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, openPending)

            val refreshIntent = Intent(context, BatteryGaugeWidgetProvider::class.java).apply {
                action = ACTION_WIDGET_REFRESH
            }
            val refreshPending = PendingIntent.getBroadcast(
                context,
                1,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_refresh_btn, refreshPending)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
