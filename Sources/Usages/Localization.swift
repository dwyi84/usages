import Foundation

public struct L10n {
    public static var isKorean: Bool {
        if let lang = Locale.preferredLanguages.first {
            return lang.hasPrefix("ko")
        }
        return Locale.current.identifier.hasPrefix("ko")
    }
    
    // Header & Titles
    public static var appTitle: String { "AI Usages" }
    public static var refreshTooltip: String { isKorean ? "새로고침" : "Refresh" }
    
    // Tabs
    public static var tabQuotas: String { isKorean ? "한도 쿼터" : "Quotas" }
    public static var tabTokenCost: String { isKorean ? "토큰 & 비용" : "Tokens & Cost" }
    
    // Provider list section titles
    public static var activeProviders: String { isKorean ? "사용 중인 프로바이더" : "Active Providers" }
    public static var availableProviders: String { isKorean ? "추가 가능한 프로바이더" : "Available Providers" }
    public static var detectedBadge: String { isKorean ? "로컬 감지됨" : "Detected" }
    public static var notDetectedBadge: String { isKorean ? "미설치" : "Not Detected" }
    
    // Services
    public static var openCodeTitle: String { "Go Subscription" }
    public static var googleAITitle: String { "Google AI Pro" }
    public static var openRouterTitle: String { "OpenRouter" }
    
    // Quota labels
    public static var fiveHourWindow: String { isKorean ? "5시간 윈도우" : "5-hour window" }
    public static var weekly: String { isKorean ? "주간" : "Weekly" }
    public static var monthly: String { isKorean ? "월간" : "Monthly" }
    public static var geminiModels: String { isKorean ? "Gemini 모델" : "Gemini Models" }
    public static var claudeAndGpt: String { "Claude & GPT" }
    public static var geminiArgon: String { "Gemini 4 Argon" }
    
    // Token & Cost labels
    public static var balance: String { isKorean ? "잔액" : "Balance" }
    public static var todaySpend: String { isKorean ? "오늘 사용액" : "Today Spend" }
    public static var monthSpend: String { isKorean ? "당월 사용액" : "Month Spend" }
    public static var totalTokens: String { isKorean ? "총 토큰" : "Total Tokens" }
    public static var promptTokens: String { isKorean ? "프롬프트" : "Prompt" }
    public static var completionTokens: String { isKorean ? "완성" : "Completion" }
    public static var noTokenProviders: String { isKorean ? "설정에서 OpenRouter API 키를 등록하면 실시간 잔액 및 토큰 사용량이 표시됩니다." : "Add an OpenRouter API key in settings to track real-time balance and token spend." }
    public static var enterOpenRouterKey: String { isKorean ? "OpenRouter API Key 입력 (sk-or-...)" : "Enter OpenRouter API Key (sk-or-...)" }
    public static var save: String { isKorean ? "저장" : "Save" }
    public static var connectKey: String { isKorean ? "API 키 설정" : "Configure Key" }
    public static var paste: String { isKorean ? "붙여넣기" : "Paste" }
    public static var usageTrend: String { isKorean ? "사용 트렌드 (Usage Trend)" : "Usage Trend" }
    public static var today: String { isKorean ? "오늘" : "Today" }
    public static var yesterday: String { isKorean ? "어제" : "Yesterday" }
    public static var last30Days: String { isKorean ? "최근 30일" : "Last 30 Days" }
    public static var moveUp: String { isKorean ? "위로 이동" : "Move Up" }
    public static var moveDown: String { isKorean ? "아래로 이동" : "Move Down" }
    
    // Units & States
    public static var remaining: String { isKorean ? "남음" : "remaining" }
    public static var quotaAvailable: String { isKorean ? "쿼터 여유" : "Quota available" }
    public static var rateLimited: String { isKorean ? "요청 한도 대기 중" : "Rate limited" }
    public static var setBillingDay: String { isKorean ? "+ 리셋일 설정" : "+ Set Reset Day" }
    public static var billingDayPrompt: String { isKorean ? "매월 리셋일 선택:" : "Select Monthly Reset Day:" }
    public static var autoSyncedTooltip: String { isKorean ? "OpenCode API에서 자동 제공되는 리셋일입니다." : "Auto-synced from OpenCode API" }
    public static var googleBillingTooltip: String { isKorean ? "Google은 리셋일 API를 제공하지 않아 직접 설정합니다. 클릭하여 변경." : "Google quota API does not expose reset date. Click to configure." }
    public static var reset: String { isKorean ? "초기화" : "Reset" }
    public static var dayUnit: String { isKorean ? "일" : "th" }
    
    // Footer & Settings
    public static var autoRefresh: String { isKorean ? "자동 리셋:" : "Auto Refresh:" }
    public static var min1: String { isKorean ? "1분" : "1m" }
    public static var min3: String { isKorean ? "3분" : "3m" }
    public static var min5: String { isKorean ? "5분" : "5m" }
    public static var min15: String { isKorean ? "15분" : "15m" }
    
    public static var launchAtLogin: String { isKorean ? "로그인 시 자동 시작" : "Launch at Login" }
    public static var quit: String { isKorean ? "종료" : "Quit" }
    public static var quitApp: String { isKorean ? "AI Usages 종료" : "Quit AI Usages" }
    public static var refreshApp: String { isKorean ? "AI Usages 새로고침" : "Refresh AI Usages" }
    
    // Updates
    public static var checkForUpdates: String { isKorean ? "업데이트 확인" : "Check for Updates" }
    public static var checking: String { isKorean ? "확인 중..." : "Checking..." }
    public static var upToDate: String { isKorean ? "최신 버전" : "Up to date" }
    public static var updateAvailable: String { isKorean ? "업데이트 가능" : "Update available" }
    public static var updateNow: String { isKorean ? "지금 업데이트" : "Update Now" }
    public static var later: String { isKorean ? "나중에" : "Later" }
    public static var updateFailed: String { isKorean ? "확인 실패" : "Check failed" }
    
    // Support
    public static var buyMeACoffee: String { isKorean ? "커피 후원하기" : "Buy me a coffee" }
}
