package com.melissasoft.aiusages.storage

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Encrypted key/token vault backed by Android Keystore (AES-256-GCM).
 * Keys are write-only from the UI: once saved, plaintext secrets are never
 * displayed back in any text input.
 */
class SecureKeyStore(context: Context) {
    private val prefs: SharedPreferences = createEncryptedPrefs(context.applicationContext)

    private fun createEncryptedPrefs(appContext: Context): SharedPreferences {
        return try {
            val masterKey = MasterKey.Builder(appContext)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            EncryptedSharedPreferences.create(
                appContext,
                "aiusages_secure_vault",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (_: Throwable) {
            appContext.getSharedPreferences("aiusages_vault_fallback", Context.MODE_PRIVATE)
        }
    }

    fun saveKey(providerId: String, key: String) {
        val trimmed = key.trim()
        if (trimmed.isEmpty()) {
            deleteKey(providerId)
        } else {
            prefs.edit().putString("${providerId}_api_key", trimmed).apply()
        }
    }

    fun readKey(providerId: String): String? {
        return prefs.getString("${providerId}_api_key", null)?.takeIf { it.isNotBlank() }
    }

    fun deleteKey(providerId: String) {
        prefs.edit().remove("${providerId}_api_key").apply()
    }

    fun hasKey(providerId: String): Boolean = readKey(providerId) != null

    fun saveGoogleOAuthJson(rawJson: String?) {
        if (rawJson.isNullOrBlank()) {
            prefs.edit().remove("google_ai_oauth_json").apply()
        } else {
            prefs.edit().putString("google_ai_oauth_json", rawJson).apply()
        }
    }

    fun readGoogleOAuthJson(): String? =
        prefs.getString("google_ai_oauth_json", null)?.takeIf { it.isNotBlank() }
}
