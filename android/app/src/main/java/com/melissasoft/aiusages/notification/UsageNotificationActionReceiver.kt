package com.melissasoft.aiusages.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import com.melissasoft.aiusages.storage.AppSettingsRepository
import com.melissasoft.aiusages.worker.UsageRefreshWorker

/**
 * Handles compact notification refresh taps and restores the persistent indicator after device boot.
 */
class UsageNotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val appContext = context.applicationContext
        when (action) {
            UsageNotificationManager.ACTION_NOTIFICATION_REFRESH -> {
                val work = OneTimeWorkRequestBuilder<UsageRefreshWorker>()
                    .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                    .build()
                WorkManager.getInstance(appContext).enqueue(work)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                val settings = AppSettingsRepository(appContext)
                UsageRefreshWorker.schedulePeriodic(appContext, settings.refreshIntervalSeconds)
                UsageNotificationManager.updateOrShow(appContext)
            }
        }
    }
}
