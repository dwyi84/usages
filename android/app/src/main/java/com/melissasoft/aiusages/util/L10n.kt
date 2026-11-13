package com.melissasoft.aiusages.util

import java.util.Locale

/**
 * Bilingual English / Korean localization mirroring Localization.swift.
 */
object L10n {
    val isKorean: Boolean
        get() = Locale.getDefault().language.equals("ko", ignoreCase = true)

    val appTitle: String get() = "AI Usages"
    val refreshTooltip: String get() = if (isKorean) "새로고침" else "Refresh"

    // Services
    val openCodeTitle: String get() = "OpenCode Go"
    val googleAITitle: String get() = "Google AI Pro"
    val openRouterTitle: String get() = "OpenRouter"

    // Quota labels
    val fiveHourWindow: String get() = if (isKorean) "5시간 윈도우" else "5-hour window"
    val weekly: String get() = if (isKorean) "주간" else "Weekly"
    val monthly: String get() = if (isKorean) "월간" else "Monthly"
    val geminiModels: String get() = if (isKorean) "Gemini 모델" else "Gemini Models"
    val claudeAndGpt: String get() = "Claude & GPT"
    val geminiArgon: String get() = "Gemini 4 Argon"

    // Token & Cost labels
    val balance: String get() = if (isKorean) "잔액" else "Balance"
    val totalTokens: String get() = if (isKorean) "총 토큰" else "Total Tokens"
    val totalSteps: String get() = if (isKorean) "총 스텝" else "Total Steps"
    val enterOpenRouterKey: String
        get() = if (isKorean) "OpenRouter API Key 입력 (sk-or-...)" else "Enter OpenRouter API Key (sk-or-...)"
    val enterOpenCodeKey: String
        get() = if (isKorean) "OpenCode Go API Key / 토큰 (oc_sk_...)" else "OpenCode Go Key / Token (oc_sk_...)"
    val enterGoogleToken: String
        get() = if (isKorean) "Google AI OAuth 토큰 또는 agy 인증 JSON" else "Google AI OAuth Token or agy auth JSON"
    val save: String get() = if (isKorean) "저장" else "Save"
    val usageTrend: String get() = if (isKorean) "사용 트렌드" else "Usage Trend"
    val detailedTrendTitle: String get() = if (isKorean) "상세 사용 트렌드" else "Detailed Usage Trend"
    val dailyAverage: String get() = if (isKorean) "일평균 사용" else "Daily Avg"
    val peakDay: String get() = if (isKorean) "최대 사용일" else "Peak Day"
    val keySavedSecurely: String get() = if (isKorean) "API Key 안전 등록됨" else "API Key Configured"
    val replaceKey: String get() = if (isKorean) "새 키 등록" else "Replace Key"
    val deleteKey: String get() = if (isKorean) "키 삭제" else "Delete Key"
    val trendChartTip: String
        get() = if (isKorean) "막대를 터치/드래그하면 일별 토큰과 비용을 확인할 수 있습니다." else "Touch or drag across bars to inspect daily tokens and spend."
    val today: String get() = if (isKorean) "오늘" else "Today"
    val yesterday: String get() = if (isKorean) "어제" else "Yesterday"
    val last30Days: String get() = if (isKorean) "최근 30일" else "Last 30 Days"
    val moveUp: String get() = if (isKorean) "위로 이동" else "Move Up"
    val moveDown: String get() = if (isKorean) "아래로 이동" else "Move Down"

    // Units & States
    val remaining: String get() = if (isKorean) "남음" else "remaining"
    val quotaAvailable: String get() = if (isKorean) "쿼터 여유" else "Quota available"
    val rateLimited: String get() = if (isKorean) "요청 한도 대기 중" else "Rate limited"
    val setBillingDay: String get() = if (isKorean) "+ 리셋일 설정" else "+ Set Reset Day"
    val billingDayPrompt: String get() = if (isKorean) "매월 리셋일 선택:" else "Select Monthly Reset Day:"
    val reset: String get() = if (isKorean) "초기화" else "Reset"
    val dayUnit: String get() = if (isKorean) "일" else "th"

    // Header & Settings
    val min1: String get() = if (isKorean) "1분" else "1m"
    val min3: String get() = if (isKorean) "3분" else "3m"
    val min5: String get() = if (isKorean) "5분" else "5m"
    val min15: String get() = if (isKorean) "15분" else "15m"

    // Updates
    val checkForUpdates: String get() = if (isKorean) "업데이트 확인" else "Check for Updates"
    val checking: String get() = if (isKorean) "확인 중..." else "Checking..."
    val upToDate: String get() = if (isKorean) "최신 버전" else "Up to date"
    val updateAvailable: String get() = if (isKorean) "업데이트 가능" else "Update available"
    val updateNow: String get() = if (isKorean) "다운로드 페이지 열기" else "Open Release"
    val later: String get() = if (isKorean) "나중에" else "Later"
    val updateFailed: String get() = if (isKorean) "확인 실패" else "Check failed"

    // Support & Android extras
    val buyMeACoffee: String get() = if (isKorean) "커피 후원하기" else "Buy me a coffee"
    val importFile: String get() = if (isKorean) "파일 가져오기" else "Import File"
    val providerMgmtTitle: String
        get() = if (isKorean) "프로바이더 활성화 및 관리" else "Provider Activation & Management"
    val collapse: String get() = if (isKorean) "접기" else "Collapse"
    val manage: String get() = if (isKorean) "펼치기" else "Manage"
    val noActiveProviders: String
        get() = if (isKorean) "활성화된 프로바이더가 없습니다." else "No active providers."
    val noActiveProvidersHint: String
        get() = if (isKorean) "아래 '프로바이더 활성화 및 관리'에서 사용할 서비스를 켜주세요." else "Toggle on the services you want to track below."
}
