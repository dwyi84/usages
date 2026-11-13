package com.melissasoft.aiusages.storage

import android.content.Context
import android.content.SharedPreferences
import com.melissasoft.aiusages.model.GaugeStatus
import com.melissasoft.aiusages.model.ProviderKeySpec
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

data class WidgetGaugeCacheEntry(
    val percent: Double,
    val status: GaugeStatus,
    val summaryLine: String,
    val compactChip: String = "",
    val resetHint: String = ""
)

data class WidgetCacheState(
    val entries: List<WidgetGaugeCacheEntry>,
    val daysUntilReset: Int,
    val updatedAtText: String
)

class AppSettingsRepository(context: Context) {
    private val appContext = context.applicationContext
    private val prefs: SharedPreferences =
        appContext.getSharedPreferences("aiusages_prefs", Context.MODE_PRIVATE)
    val keyStore = SecureKeyStore(appContext)

    val importedOpenCodeDbFile: File
        get() = File(appContext.filesDir, "imported_opencode.db")

    val importedGoogleStepsDbFile: File
        get() = File(appContext.filesDir, "imported_conversation_summaries.db")

    var refreshIntervalSeconds: Long
        get() {
            val v = prefs.getLong("refreshIntervalSeconds", 300L)
            return if (v >= 60L) v else 300L
        }
        set(value) {
            prefs.edit().putLong("refreshIntervalSeconds", value.coerceAtLeast(60L)).apply()
        }

    var enabledProviderIds: Set<String>
        get() = prefs.getStringSet("enabledProviderIds", emptySet())?.toSet() ?: emptySet()
        set(value) {
            prefs.edit().putStringSet("enabledProviderIds", value).apply()
        }

    var providerOrder: List<String>
        get() {
            val raw = prefs.getString("providerOrder", null)
            val parsed = if (raw.isNullOrBlank()) {
                emptyList()
            } else {
                raw.split(",").filter { it.isNotBlank() }
            }
            val merged = parsed.toMutableList()
            for (def in ProviderKeySpec.defaultPopularityOrder) {
                if (!merged.contains(def)) merged.add(def)
            }
            return merged
        }
        set(value) {
            prefs.edit().putString("providerOrder", value.joinToString(",")).apply()
        }

    var googleBillingDayOfMonth: Int
        get() = prefs.getInt("googleBillingDayOfMonth", 0)
        set(value) {
            prefs.edit().putInt("googleBillingDayOfMonth", value.coerceIn(0, 31)).apply()
        }

    var statusBarIndicatorEnabled: Boolean
        get() = prefs.getBoolean("statusBarIndicatorEnabled", true)
        set(value) {
            prefs.edit().putBoolean("statusBarIndicatorEnabled", value).apply()
        }

    fun selectedMetricKey(providerId: String): String {
        val raw = prefs.getString("selectedMetricKey_$providerId", null)
        if (!raw.isNullOrBlank()) return raw
        return when (providerId) {
            "opencode" -> "opencode_5h"
            "google_ai" -> "google_gemini_5h"
            else -> ""
        }
    }

    fun setSelectedMetricKey(providerId: String, key: String) {
        prefs.edit().putString("selectedMetricKey_$providerId", key).apply()
    }

    fun isProviderEnabled(id: String): Boolean = enabledProviderIds.contains(id)

    fun setProviderEnabled(id: String, enabled: Boolean) {
        val next = enabledProviderIds.toMutableSet()
        if (enabled) next.add(id) else next.remove(id)
        enabledProviderIds = next
    }

    fun moveProviderUp(id: String) {
        val list = providerOrder.toMutableList()
        val idx = list.indexOf(id)
        if (idx > 0) {
            val tmp = list[idx - 1]
            list[idx - 1] = list[idx]
            list[idx] = tmp
            providerOrder = list
        }
    }

    fun moveProviderDown(id: String) {
        val list = providerOrder.toMutableList()
        val idx = list.indexOf(id)
        if (idx in 0 until list.lastIndex) {
            val tmp = list[idx + 1]
            list[idx + 1] = list[idx]
            list[idx] = tmp
            providerOrder = list
        }
    }

    fun saveProviderKey(providerId: String, rawKey: String) {
        keyStore.saveKey(providerId, rawKey)
        if (rawKey.trim().isNotEmpty()) {
            setProviderEnabled(providerId, true)
        }
    }

    fun deleteProviderKey(providerId: String) {
        keyStore.deleteKey(providerId)
        if (providerId == "google_ai") {
            keyStore.saveGoogleOAuthJson(null)
            keyStore.saveGoogleAccountEmail(null)
        }
        setProviderEnabled(providerId, false)
    }

    fun saveWidgetCache(state: WidgetCacheState) {
        val root = JSONObject().apply {
            put("daysUntilReset", state.daysUntilReset)
            put("updatedAtText", state.updatedAtText)
            val arr = JSONArray()
            for (e in state.entries) {
                arr.put(
                    JSONObject().apply {
                        put("percent", e.percent)
                        put("status", e.status.name)
                        put("summaryLine", e.summaryLine)
                        put("compactChip", e.compactChip)
                        put("resetHint", e.resetHint)
                    }
                )
            }
            put("entries", arr)
        }
        prefs.edit().putString("widget_cache_json", root.toString()).apply()
    }

    fun readWidgetCache(): WidgetCacheState? {
        val raw = prefs.getString("widget_cache_json", null) ?: return null
        return try {
            val root = JSONObject(raw)
            val days = root.optInt("daysUntilReset", 999)
            val updated = root.optString("updatedAtText", "--:--")
            val arr = root.optJSONArray("entries") ?: JSONArray()
            val list = buildList {
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    val status = runCatching {
                        GaugeStatus.valueOf(obj.optString("status", "UNKNOWN"))
                    }.getOrDefault(GaugeStatus.UNKNOWN)
                    add(
                        WidgetGaugeCacheEntry(
                            percent = obj.optDouble("percent", 0.0),
                            status = status,
                            summaryLine = obj.optString("summaryLine", ""),
                            compactChip = obj.optString("compactChip", ""),
                            resetHint = obj.optString("resetHint", "")
                        )
                    )
                }
            }
            WidgetCacheState(list, days, updated)
        } catch (_: Throwable) {
            null
        }
    }
}
