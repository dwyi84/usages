package com.melissasoft.aiusages.provider

import com.melissasoft.aiusages.BuildConfig
import com.melissasoft.aiusages.model.ReleaseInfo
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

enum class UpdateState {
    IDLE,
    CHECKING,
    UP_TO_DATE,
    UPDATE_AVAILABLE,
    FAILED
}

class UpdaterRepository(
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(8, TimeUnit.SECONDS)
        .build(),
    private val latestReleaseUrl: String =
        "https://api.github.com/repos/dwyi84/usages/releases/latest"
) {
    suspend fun fetchLatestRelease(): ReleaseInfo? = withContext(Dispatchers.IO) {
        val req = Request.Builder()
            .url(latestReleaseUrl)
            .get()
            .header("User-Agent", "AIUsages-Android/${BuildConfig.VERSION_NAME}")
            .build()
        return@withContext try {
            client.newCall(req).execute().use { resp ->
                if (!resp.isSuccessful) return@use null
                val body = resp.body?.string() ?: return@use null
                parseReleaseJson(body)
            }
        } catch (_: Throwable) {
            null
        }
    }

    companion object {
        fun parseReleaseJson(rawJson: String): ReleaseInfo? {
            return try {
                val root = JSONObject(rawJson)
                val rawTag = root.optString("tag_name", "").trim()
                val htmlUrl = root.optString("html_url", "").trim()
                if (rawTag.isEmpty() || htmlUrl.isEmpty()) return null
                val tag = rawTag.removePrefix("v")
                val assets = root.optJSONArray("assets")
                var apkUrl: String? = null
                if (assets != null) {
                    for (i in 0 until assets.length()) {
                        val url = assets.getJSONObject(i).optString("browser_download_url", "")
                        if (url.endsWith(".apk", ignoreCase = true)) {
                            apkUrl = url
                            break
                        }
                    }
                }
                ReleaseInfo(version = tag, htmlUrl = htmlUrl, apkDownloadUrl = apkUrl)
            } catch (_: Throwable) {
                null
            }
        }

        fun isNewer(remoteVersion: String, currentVersion: String = BuildConfig.VERSION_NAME): Boolean {
            val remoteParts = remoteVersion.removePrefix("v").split(".").map { it.toIntOrNull() ?: 0 }
            val currentParts = currentVersion.removePrefix("v").split(".").map { it.toIntOrNull() ?: 0 }
            val count = maxOf(remoteParts.size, currentParts.size)
            for (i in 0 until count) {
                val r = remoteParts.getOrElse(i) { 0 }
                val c = currentParts.getOrElse(i) { 0 }
                if (r != c) return r > c
            }
            return false
        }
    }
}
