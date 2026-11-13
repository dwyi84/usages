package com.melissasoft.aiusages

import android.app.Application
import com.melissasoft.aiusages.provider.UsageManager

class AIUsagesApp : Application() {
    lateinit var usageManager: UsageManager
        private set

    override fun onCreate() {
        super.onCreate()
        usageManager = UsageManager(this)
    }
}
