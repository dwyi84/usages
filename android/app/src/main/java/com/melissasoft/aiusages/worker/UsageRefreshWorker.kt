package com.melissasoft.aiusages.worker

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.melissasoft.aiusages.AIUsagesApp
import java.util.concurrent.TimeUnit

class UsageRefreshWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val manager = (applicationContext as AIUsagesApp).usageManager
        manager.refreshAll()
        return Result.success()
    }

    companion object {
        private const val PERIODIC_WORK_NAME = "aiusages_periodic_refresh"

        fun schedulePeriodic(context: Context, intervalSeconds: Long) {
            // Android WorkManager enforces a 15-minute floor for background periodic tasks.
            // Shorter intervals (1m/3m/5m) are honored by the foreground coroutine ticker.
            val minutes = (intervalSeconds / 60L).coerceAtLeast(15L)
            val request = PeriodicWorkRequestBuilder<UsageRefreshWorker>(minutes, TimeUnit.MINUTES)
                .build()
            WorkManager.getInstance(context.applicationContext).enqueueUniquePeriodicWork(
                PERIODIC_WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request
            )
        }
    }
}
