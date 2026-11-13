package com.melissasoft.aiusages

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.lifecycleScope
import com.melissasoft.aiusages.ui.MainScreen
import com.melissasoft.aiusages.ui.theme.AIUsagesTheme
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val usageManager = (application as AIUsagesApp).usageManager
        lifecycleScope.launch {
            usageManager.refreshAll()
            usageManager.checkForUpdates(silent = true)
        }

        setContent {
            AIUsagesTheme {
                MainScreen(usageManager = usageManager)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        val usageManager = (application as AIUsagesApp).usageManager
        lifecycleScope.launch {
            usageManager.refreshAll()
        }
    }
}
