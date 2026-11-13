# AI Usages for Android

Native Kotlin + Jetpack Compose Android port of **AI Usages** (`com.melissasoft.aiusages`).

## Features

- **4-Segment Battery Gauges & Home Screen Widget**: Renders the signature 1–3 vertical 4-segment quota/balance bars both in the app header and as a resizable Android Home Screen Widget (`BatteryGaugeWidgetProvider`) with tap-to-refresh.
- **Live Quota & Spend Tracking**:
  - **OpenCode Go**: Queries `https://opencode.ai/zen/go/v1/usage` (5-hour rolling, weekly, monthly windows + reset countdowns). Supports direct API key / token entry or importing `opencode.db` / `auth.json` (also extracts 30-day usage history from `session_message`).
  - **Google AI Pro (Antigravity)**: Queries Google Cloud Code quota (`Gemini Models`, `Claude & GPT`, optional `Gemini 4 Argon`), supports manual billing reset day with month-length clamping, accepts OAuth tokens or Antigravity JSON (`go-keyring-base64:...` / `refresh_token` auto-refresh), and imports `conversation_summaries.db` for 30-day step trends.
  - **OpenRouter**: Parallel `/credits`, `/key`, and `/activity` requests with balance, today/month spend, and UTC-aligned 30-day chart.
  - **Additional Providers**: Codex, Claude, Cursor, Copilot, Perplexity, DeepSeek with write-only encrypted credential storage.
- **Interactive 30-Day Trend Modal**: Touch/drag scrubbing across all 30 daily bars with anchored date, token/step count, and USD cost inspection.
- **Hardware-Backed Key Vault**: Uses `EncryptedSharedPreferences` + Android Keystore (`AES256_GCM`).
- **Bilingual UI**: Automatically switches between Korean (`ko`) and English based on Android system locale.

## Build APK

```bash
cd android
./gradlew testDebugUnitTest assembleDebug assembleRelease
```

Outputs:
- Debug APK: `android/app/build/outputs/apk/debug/app-debug.apk`
- Release APK: `android/app/build/outputs/apk/release/app-release.apk`

For custom release signing, set `RELEASE_STORE_FILE`, `RELEASE_STORE_PASSWORD`, `RELEASE_KEY_ALIAS`, and `RELEASE_KEY_PASSWORD` environment variables before running `assembleRelease`.
