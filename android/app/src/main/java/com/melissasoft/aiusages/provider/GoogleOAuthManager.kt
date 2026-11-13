package com.melissasoft.aiusages.provider

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.InetAddress
import java.net.ServerSocket
import java.net.SocketTimeoutException
import java.net.URI
import java.net.URLDecoder
import java.net.URLEncoder
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64
import java.util.concurrent.TimeUnit

data class GoogleOAuthClientConfig(
    val clientId: String,
    val clientSecret: String? = null,
    val clientType: ClientType = ClientType.DESKTOP
) {
    enum class ClientType { DESKTOP, ANDROID, WEB }

    fun toJsonString(): String {
        return JSONObject().apply {
            put("client_id", clientId)
            if (!clientSecret.isNullOrBlank()) put("client_secret", clientSecret)
            put("client_type", clientType.name)
        }.toString()
    }
}

data class PendingOAuthSession(
    val clientConfig: GoogleOAuthClientConfig,
    val redirectUri: String,
    val codeVerifier: String,
    val state: String,
    val authorizationUrl: String
)

/**
 * Pure RFC 8252 Google OAuth 2.0 PKCE authenticator for user-supplied OAuth Client IDs.
 * Does not embed any third-party/first-party CLI client secrets.
 */
class GoogleOAuthManager(
    private val client: OkHttpClient = defaultHttpClient(),
    private val authEndpoint: String = "https://accounts.google.com/o/oauth2/v2/auth",
    private val tokenEndpoint: String = "https://oauth2.googleapis.com/token",
    private val userInfoEndpoint: String = "https://www.googleapis.com/oauth2/v2/userinfo"
) {

    class LoopbackListener : AutoCloseable {
        val serverSocket = ServerSocket(0, 2, InetAddress.getByName("127.0.0.1")).apply {
            soTimeout = 180_000
        }
        val port: Int get() = serverSocket.localPort
        val redirectUri: String get() = "http://127.0.0.1:$port/oauth/callback"

        suspend fun awaitRedirectRequest(expectedState: String, isKorean: Boolean): Result<String> =
            withContext(Dispatchers.IO) {
                try {
                    while (!serverSocket.isClosed) {
                        val socket = serverSocket.accept()
                        socket.use { s ->
                            s.soTimeout = 5_000
                            val reader = BufferedReader(InputStreamReader(s.getInputStream()))
                            val requestLine = reader.readLine().orEmpty()
                            if (requestLine.isNotBlank()) {
                                // Ignore browser favicon probes; wait for actual OAuth callback path.
                                val pathWithQuery = requestLine.split(" ").getOrNull(1) ?: "/"
                                if (!pathWithQuery.startsWith("/oauth/callback")) {
                                    writeHttpResponse(s.getOutputStream(), 404, "<html><body>Not Found</body></html>")
                                } else {
                                    val fullUrl = "http://127.0.0.1:$port$pathWithQuery"
                                    val parsed = extractAuthCodeFromRedirect(fullUrl, expectedState)
                                    val body = if (parsed.isSuccess) {
                                        successHtml(isKorean)
                                    } else {
                                        failureHtml(parsed.exceptionOrNull()?.message.orEmpty(), isKorean)
                                    }
                                    writeHttpResponse(s.getOutputStream(), 200, body)
                                    return@withContext parsed
                                }
                            }
                        }
                    }
                    Result.failure(IllegalStateException("OAuth listener closed"))
                } catch (_: SocketTimeoutException) {
                    Result.failure(IllegalStateException("OAuth login timed out"))
                } catch (t: Throwable) {
                    Result.failure(t)
                } finally {
                    close()
                }
            }

        override fun close() {
            runCatching { serverSocket.close() }
        }
    }

    suspend fun exchangeCodeForTokens(
        session: PendingOAuthSession,
        code: String
    ): Result<GoogleOAuthBundle> = withContext(Dispatchers.IO) {
        val form = FormBody.Builder()
            .add("grant_type", "authorization_code")
            .add("code", code.trim())
            .add("client_id", session.clientConfig.clientId.trim())
            .add("redirect_uri", session.redirectUri)
            .add("code_verifier", session.codeVerifier)
        if (!session.clientConfig.clientSecret.isNullOrBlank()) {
            form.add("client_secret", session.clientConfig.clientSecret.trim())
        }

        val req = Request.Builder()
            .url(tokenEndpoint)
            .post(form.build())
            .build()

        try {
            client.newCall(req).execute().use { resp ->
                val rawBody = resp.body?.string().orEmpty()
                if (!resp.isSuccessful) {
                    val msg = parseTokenError(rawBody) ?: "HTTP ${resp.code}"
                    return@withContext Result.failure(IllegalStateException(msg))
                }
                val json = JSONObject(rawBody)
                val access = json.optString("access_token", "").takeIf { it.isNotBlank() }
                    ?: return@withContext Result.failure(IllegalStateException("Missing access_token"))
                val refresh = json.optString("refresh_token", "").takeIf { it.isNotBlank() }
                val email = fetchUserEmail(access)
                Result.success(
                    GoogleOAuthBundle(
                        accessToken = access,
                        refreshToken = refresh,
                        clientId = session.clientConfig.clientId.trim(),
                        clientSecret = session.clientConfig.clientSecret?.trim()?.takeIf { it.isNotBlank() },
                        email = email
                    )
                )
            }
        } catch (t: Throwable) {
            Result.failure(t)
        }
    }

    private fun fetchUserEmail(accessToken: String): String? {
        val req = Request.Builder()
            .url(userInfoEndpoint)
            .header("Authorization", "Bearer $accessToken")
            .get()
            .build()
        return try {
            client.newCall(req).execute().use { resp ->
                if (!resp.isSuccessful) return null
                val json = JSONObject(resp.body?.string().orEmpty())
                json.optString("email", "").takeIf { it.isNotBlank() }
            }
        } catch (_: Throwable) {
            null
        }
    }

    fun createSession(
        clientConfig: GoogleOAuthClientConfig,
        redirectUri: String,
        scope: String = DEFAULT_SCOPE
    ): PendingOAuthSession {
        val verifier = generateCodeVerifier()
        val challenge = computeCodeChallengeS256(verifier)
        val state = generateState()
        val url = buildAuthorizationUrl(
            authEndpoint = authEndpoint,
            clientId = clientConfig.clientId,
            redirectUri = redirectUri,
            codeChallenge = challenge,
            state = state,
            scope = scope
        )
        return PendingOAuthSession(
            clientConfig = clientConfig,
            redirectUri = redirectUri,
            codeVerifier = verifier,
            state = state,
            authorizationUrl = url
        )
    }

    companion object {
        const val CUSTOM_ANDROID_REDIRECT_URI = "com.melissasoft.aiusages:/oauth2redirect"
        const val DEFAULT_SCOPE =
            "openid https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/cloud-platform"

        private val secureRandom = SecureRandom()

        private fun defaultHttpClient(): OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .build()

        fun generateCodeVerifier(): String {
            val bytes = ByteArray(48)
            secureRandom.nextBytes(bytes)
            return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
        }

        fun computeCodeChallengeS256(codeVerifier: String): String {
            val digest = MessageDigest.getInstance("SHA-256")
                .digest(codeVerifier.toByteArray(Charsets.US_ASCII))
            return Base64.getUrlEncoder().withoutPadding().encodeToString(digest)
        }

        fun generateState(): String {
            val bytes = ByteArray(18)
            secureRandom.nextBytes(bytes)
            return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
        }

        fun buildAuthorizationUrl(
            authEndpoint: String = "https://accounts.google.com/o/oauth2/v2/auth",
            clientId: String,
            redirectUri: String,
            codeChallenge: String,
            state: String,
            scope: String = DEFAULT_SCOPE
        ): String {
            fun enc(v: String) = URLEncoder.encode(v, "UTF-8")
            return buildString {
                append(authEndpoint)
                append("?client_id=").append(enc(clientId.trim()))
                append("&redirect_uri=").append(enc(redirectUri))
                append("&response_type=code")
                append("&scope=").append(enc(scope))
                append("&code_challenge=").append(enc(codeChallenge))
                append("&code_challenge_method=S256")
                append("&access_type=offline")
                append("&prompt=consent")
                append("&include_granted_scopes=true")
                append("&state=").append(enc(state))
            }
        }

        fun parseOAuthClientConfig(rawJson: String?): GoogleOAuthClientConfig? {
            val trimmed = rawJson?.trim().orEmpty()
            if (!trimmed.startsWith("{")) return null
            return try {
                val root = JSONObject(trimmed)
                // Do not confuse an already-authenticated token bundle with an empty client_secret config.
                val tokenObj = root.optJSONObject("token")
                if (root.has("access_token") || tokenObj?.has("access_token") == true) {
                    val clientObj = root.optJSONObject("installed") ?: root.optJSONObject("web") ?: root
                    val cid = clientObj.optString("client_id", "").takeIf { it.isNotBlank() } ?: return null
                    val csec = clientObj.optString("client_secret", "").takeIf { it.isNotBlank() }
                    return GoogleOAuthClientConfig(cid, csec, GoogleOAuthClientConfig.ClientType.DESKTOP)
                }

                val (obj, type) = when {
                    root.has("installed") -> root.getJSONObject("installed") to GoogleOAuthClientConfig.ClientType.DESKTOP
                    root.has("web") -> root.getJSONObject("web") to GoogleOAuthClientConfig.ClientType.WEB
                    else -> {
                        val parsedType = runCatching {
                            GoogleOAuthClientConfig.ClientType.valueOf(root.optString("client_type", "DESKTOP"))
                        }.getOrDefault(GoogleOAuthClientConfig.ClientType.DESKTOP)
                        root to parsedType
                    }
                }
                val clientId = obj.optString("client_id", "").trim()
                if (clientId.isEmpty()) return null
                val secret = obj.optString("client_secret", "").trim().takeIf { it.isNotBlank() }
                GoogleOAuthClientConfig(
                    clientId = clientId,
                    clientSecret = secret,
                    clientType = type
                )
            } catch (_: Throwable) {
                null
            }
        }

        fun extractAuthCodeFromRedirect(rawInput: String, expectedState: String?): Result<String> {
            val trimmed = rawInput.trim()
            if (trimmed.isEmpty()) {
                return Result.failure(IllegalArgumentException("Empty authorization response"))
            }
            val looksLikeRedirect = trimmed.contains(":/") ||
                trimmed.contains("?") ||
                trimmed.contains("code=") ||
                trimmed.contains("error=")
            if (!looksLikeRedirect) {
                return Result.success(trimmed)
            }
            val query = try {
                if (trimmed.contains(":/")) URI(trimmed).rawQuery.orEmpty() else trimmed.substringAfter("?", "")
            } catch (_: Throwable) {
                trimmed.substringAfter("?", "")
            }
            val params = parseQueryParams(query)
            val err = params["error"]
            if (!err.isNullOrBlank()) {
                return Result.failure(IllegalStateException("Google OAuth error: $err"))
            }
            val actualState = params["state"]
            if (!expectedState.isNullOrBlank() && !actualState.isNullOrBlank() && actualState != expectedState) {
                return Result.failure(IllegalStateException("OAuth state mismatch"))
            }
            val code = params["code"]?.takeIf { it.isNotBlank() }
                ?: return Result.failure(IllegalArgumentException("Missing code parameter"))
            return Result.success(code)
        }

        private fun parseQueryParams(query: String): Map<String, String> {
            if (query.isBlank()) return emptyMap()
            val out = LinkedHashMap<String, String>()
            for (pair in query.split("&")) {
                val eq = pair.indexOf('=')
                if (eq <= 0) continue
                val key = URLDecoder.decode(pair.substring(0, eq), "UTF-8")
                val valStr = URLDecoder.decode(pair.substring(eq + 1), "UTF-8")
                out[key] = valStr
            }
            return out
        }

        private fun parseTokenError(rawBody: String): String? {
            if (rawBody.isBlank()) return null
            return try {
                val obj = JSONObject(rawBody)
                val err = obj.optString("error", "")
                val desc = obj.optString("error_description", "")
                listOf(err, desc).filter { it.isNotBlank() }.joinToString(": ").takeIf { it.isNotBlank() }
            } catch (_: Throwable) {
                null
            }
        }

        private fun writeHttpResponse(out: java.io.OutputStream, statusCode: Int, htmlBody: String) {
            val bytes = htmlBody.toByteArray(Charsets.UTF_8)
            val reason = if (statusCode == 200) "OK" else "Not Found"
            val headers = buildString {
                append("HTTP/1.1 $statusCode $reason\r\n")
                append("Content-Type: text/html; charset=utf-8\r\n")
                append("Content-Length: ${bytes.size}\r\n")
                append("Connection: close\r\n\r\n")
            }.toByteArray(Charsets.US_ASCII)
            out.write(headers)
            out.write(bytes)
            out.flush()
        }

        private fun successHtml(isKorean: Boolean): String {
            val title = if (isKorean) "Google 인증 완료" else "Google Sign-In Complete"
            val msg = if (isKorean) {
                "인증 코드가 AI Usages 앱으로 전달되었습니다. 이제 AI Usages 앱으로 돌아가 주세요."
            } else {
                "Authorization code received by AI Usages. You can now switch back to the app."
            }
            return """<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$title</title><style>body{font-family:sans-serif;background:#0f131a;color:#f3f6fa;padding:32px;text-align:center}.card{max-width:360px;margin:40px auto;background:#1c222d;border:1px solid #2e3748;border-radius:16px;padding:24px}</style></head><body><div class="card"><h2>$title</h2><p>$msg</p></div></body></html>"""
        }

        private fun failureHtml(error: String, isKorean: Boolean): String {
            val title = if (isKorean) "인증 실패" else "Sign-In Failed"
            return """<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$title</title></head><body style="font-family:sans-serif;padding:32px;text-align:center"><h2>$title</h2><p>$error</p></body></html>"""
        }
    }
}
