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
    
    // Services
    public static var openCodeTitle: String { "Go Subscription" }
    public static var googleAITitle: String { "Google AI Pro" }
    
    // Quota labels
    public static var fiveHourWindow: String { isKorean ? "5시간 윈도우" : "5-hour window" }
    public static var weekly: String { isKorean ? "주간" : "Weekly" }
    public static var monthly: String { isKorean ? "월간" : "Monthly" }
    public static var geminiModels: String { isKorean ? "Gemini 모델" : "Gemini Models" }
    public static var claudeAndGpt: String { "Claude & GPT" }
    public static var geminiArgon: String { "Gemini 4 Argon" }
    
    // Units & States
    public static var remaining: String { isKorean ? "남음" : "remaining" }
    public static var quotaAvailable: String { isKorean ? "쿼터 여유" : "Quota available" }
    public static func refreshesIn(_ text: String) -> String {
        return text
    }
    public static func renewsIn(_ text: String) -> String {
        return text
    }
    
    // Footer & Settings
    public static var autoRefresh: String { isKorean ? "자동 갱신:" : "Auto Refresh:" }
    public static var sec15: String { isKorean ? "15초" : "15s" }
    public static var sec30: String { isKorean ? "30초" : "30s" }
    public static var min1: String { isKorean ? "1분" : "1m" }
    public static var min5: String { isKorean ? "5분" : "5m" }
    
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
