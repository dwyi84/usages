import Foundation
import SwiftUI
import Security

// MARK: - Native macOS Keychain Helper for Secure Credentials
public final class KeychainHelper {
    public static let shared = KeychainHelper()
    private let defaultService = "com.melissasoft.aiusages"
    private let defaultAccount = "openrouter_api_key"
    
    public func save(key: String, service: String? = nil, account: String? = nil) {
        guard let data = key.data(using: .utf8) else { return }
        delete(service: service, account: account)
        let svc = service ?? defaultService
        let acc = account ?? defaultAccount
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc,
            kSecAttrAccount as String: acc,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    public func read(service: String? = nil, account: String? = nil) -> String? {
        let svc = service ?? defaultService
        let acc = account ?? defaultAccount
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc,
            kSecAttrAccount as String: acc,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data,
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return nil
    }
    
    public func delete(service: String? = nil, account: String? = nil) {
        let svc = service ?? defaultService
        let acc = account ?? defaultAccount
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc,
            kSecAttrAccount as String: acc
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public enum ServiceType: String, Codable, CaseIterable {
    case openCode = "OpenCode Go"
    case googleAI = "Google AI Pro"
    case openRouter = "OpenRouter"
    case codex = "Codex"
    case claude = "Claude"
    case cursor = "Cursor"
    case copilot = "Copilot"
    case perplexity = "Perplexity"
    case deepseek = "DeepSeek"
}

public enum QuotaMetricDisplay: String, Codable, CaseIterable {
    case fiveHour = "5h"
    case weekly = "weekly"
    case monthly = "monthly"
    
    public var displayName: String {
        switch self {
        case .fiveHour: return L10n.isKorean ? "5시간" : "5h"
        case .weekly: return L10n.isKorean ? "주간" : "Weekly"
        case .monthly: return L10n.isKorean ? "월간" : "Monthly"
        }
    }
}

public struct ProviderDetector {
    public static func isDetected(id: String) -> Bool {
        switch id {
        case "opencode":
            return OpenCodeProvider.shared.isAvailable
        case "google_ai":
            return GoogleAIProvider.shared.isAvailable
        case "openrouter":
            if let k = KeychainHelper.shared.read(), !k.isEmpty { return true }
            if let legacy = UserDefaults.standard.string(forKey: "openRouterApiKey"), !legacy.isEmpty { return true }
            return false
        case "codex":
            if let k = KeychainHelper.shared.read(account: "codex_api_key"), !k.isEmpty { return true }
            if ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil { return true }
            let codexPath = ("~/.codex" as NSString).expandingTildeInPath
            let openaiPath = ("~/.openai" as NSString).expandingTildeInPath
            return FileManager.default.fileExists(atPath: codexPath) || FileManager.default.fileExists(atPath: openaiPath)
        case "claude":
            if let k = KeychainHelper.shared.read(account: "claude_api_key"), !k.isEmpty { return true }
            if ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil { return true }
            let anthropicPath = ("~/.anthropic" as NSString).expandingTildeInPath
            let claudeAppPath = "/Applications/Claude.app"
            let userClaudeAppPath = ("~/Applications/Claude.app" as NSString).expandingTildeInPath
            return FileManager.default.fileExists(atPath: anthropicPath)
                || FileManager.default.fileExists(atPath: claudeAppPath)
                || FileManager.default.fileExists(atPath: userClaudeAppPath)
        case "cursor":
            let app1 = "/Applications/Cursor.app"
            let app2 = ("~/Applications/Cursor.app" as NSString).expandingTildeInPath
            let conf1 = ("~/.cursor" as NSString).expandingTildeInPath
            let conf2 = ("~/Library/Application Support/Cursor" as NSString).expandingTildeInPath
            return FileManager.default.fileExists(atPath: app1)
                || FileManager.default.fileExists(atPath: app2)
                || FileManager.default.fileExists(atPath: conf1)
                || FileManager.default.fileExists(atPath: conf2)
        case "copilot":
            let c1 = ("~/.config/github-copilot" as NSString).expandingTildeInPath
            let c2 = ("~/Library/Application Support/github-copilot" as NSString).expandingTildeInPath
            return FileManager.default.fileExists(atPath: c1) || FileManager.default.fileExists(atPath: c2)
        case "perplexity":
            if let k = KeychainHelper.shared.read(account: "perplexity_api_key"), !k.isEmpty { return true }
            return ProcessInfo.processInfo.environment["PERPLEXITY_API_KEY"] != nil
        case "deepseek":
            if let k = KeychainHelper.shared.read(account: "deepseek_api_key"), !k.isEmpty { return true }
            return ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] != nil
        default:
            return false
        }
    }
}

public enum ProviderCategory: String, Codable, CaseIterable {
    case quota = "quota"
    case tokenAndCost = "tokenAndCost"
}

public struct ProviderDescriptor: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let category: ProviderCategory
    public var isDetected: Bool
    public var isEnabled: Bool
    
    public init(id: String, name: String, category: ProviderCategory, isDetected: Bool, isEnabled: Bool) {
        self.id = id
        self.name = name
        self.category = category
        self.isDetected = isDetected
        self.isEnabled = isEnabled
    }
}

public enum GaugeStatus {
    case normal
    case warning
    case critical
    case rateLimited
    case error
    case unknown
    
    public var color: Color {
        switch self {
        case .normal: return Color.green
        case .warning: return Color.orange
        case .critical: return Color.red
        case .rateLimited: return Color.purple
        case .error: return Color.gray
        case .unknown: return Color.secondary
        }
    }
}

// MARK: - OpenCode Go Detail Windows (5h, Weekly, Monthly)
public struct OpenCodeWindows {
    public var fiveHourRemainingPercent: Double = 0.0
    public var fiveHourResetString: String = "-"
    
    public var weeklyRemainingPercent: Double = 0.0
    public var weeklyResetString: String = "-"
    
    public var monthlyRemainingPercent: Double = 0.0
    public var monthlyResetString: String = "-"
    
    public var nextBillingDateString: String = ""
    public var daysUntilBilling: Int = 0
    
    public init(
        fiveHourRemainingPercent: Double = 0.0,
        fiveHourResetString: String = "-",
        weeklyRemainingPercent: Double = 0.0,
        weeklyResetString: String = "-",
        monthlyRemainingPercent: Double = 0.0,
        monthlyResetString: String = "-",
        nextBillingDateString: String = "",
        daysUntilBilling: Int = 0
    ) {
        self.fiveHourRemainingPercent = fiveHourRemainingPercent
        self.fiveHourResetString = fiveHourResetString
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.weeklyResetString = weeklyResetString
        self.monthlyRemainingPercent = monthlyRemainingPercent
        self.monthlyResetString = monthlyResetString
        self.nextBillingDateString = nextBillingDateString
        self.daysUntilBilling = daysUntilBilling
    }
}

// MARK: - Google AI Pro Detail Groups (Gemini, Claude & GPT, Argon)
//
// Percent fields are optional on purpose. The quota API only returns the groups
// that exist for the signed-in account (Argon is frequently absent). A missing
// group must not be treated as "0% remaining", otherwise `overallRemainingPercent`
// collapses to 0 and the menu bar shows a false critical state.
public struct GoogleAIGroupLimits {
    public var geminiWeeklyRemainingPercent: Double? = nil
    public var geminiWeeklyResetString: String = "-"
    public var geminiFiveHourRemainingPercent: Double? = nil
    public var geminiFiveHourResetString: String = "-"
    
    public var claudeWeeklyRemainingPercent: Double? = nil
    public var claudeWeeklyResetString: String = "-"
    public var claudeFiveHourRemainingPercent: Double? = nil
    public var claudeFiveHourResetString: String = "-"
    
    public var argonWeeklyRemainingPercent: Double? = nil
    public var argonWeeklyResetString: String = "-"
    
    /// Remaining percentage across the groups the account actually has.
    /// Weekly limits are preferred; if none are reported, fall back to the
    /// 5-hour windows so a partial response still produces a sensible value.
    public var overallRemainingPercent: Double {
        let weekly = [
            geminiWeeklyRemainingPercent,
            claudeWeeklyRemainingPercent,
            argonWeeklyRemainingPercent
        ].compactMap { $0 }
        if let minimum = weekly.min() {
            return minimum
        }
        let fiveHour = [geminiFiveHourRemainingPercent, claudeFiveHourRemainingPercent].compactMap { $0 }
        return fiveHour.min() ?? 0.0
    }
    
    public var hasAnyKnownQuota: Bool {
        geminiWeeklyRemainingPercent != nil
            || geminiFiveHourRemainingPercent != nil
            || claudeWeeklyRemainingPercent != nil
            || claudeFiveHourRemainingPercent != nil
            || argonWeeklyRemainingPercent != nil
    }
    
    public var nextBillingDateString: String = ""
    public var daysUntilBilling: Int = 0
    
    public init(
        geminiWeeklyRemainingPercent: Double? = nil,
        geminiWeeklyResetString: String = "-",
        geminiFiveHourRemainingPercent: Double? = nil,
        geminiFiveHourResetString: String = "-",
        claudeWeeklyRemainingPercent: Double? = nil,
        claudeWeeklyResetString: String = "-",
        claudeFiveHourRemainingPercent: Double? = nil,
        claudeFiveHourResetString: String = "-",
        argonWeeklyRemainingPercent: Double? = nil,
        argonWeeklyResetString: String = "-",
        nextBillingDateString: String = "",
        daysUntilBilling: Int = 0
    ) {
        self.geminiWeeklyRemainingPercent = geminiWeeklyRemainingPercent
        self.geminiWeeklyResetString = geminiWeeklyResetString
        self.geminiFiveHourRemainingPercent = geminiFiveHourRemainingPercent
        self.geminiFiveHourResetString = geminiFiveHourResetString
        self.claudeWeeklyRemainingPercent = claudeWeeklyRemainingPercent
        self.claudeWeeklyResetString = claudeWeeklyResetString
        self.claudeFiveHourRemainingPercent = claudeFiveHourRemainingPercent
        self.claudeFiveHourResetString = claudeFiveHourResetString
        self.argonWeeklyRemainingPercent = argonWeeklyRemainingPercent
        self.argonWeeklyResetString = argonWeeklyResetString
        self.nextBillingDateString = nextBillingDateString
        self.daysUntilBilling = daysUntilBilling
    }
}

public struct ServiceUsageSnapshot {
    public var service: ServiceType
    public var planName: String
    public var remainingPercent: Double
    public var usedPercent: Double {
        max(0.0, min(100.0, 100.0 - remainingPercent))
    }
    public var billingDateString: String
    public var daysUntilBilling: Int
    public var status: GaugeStatus
    public var lastUpdated: Date
    public var isAvailable: Bool
    
    public var openCodeWindows: OpenCodeWindows
    public var googleGroups: GoogleAIGroupLimits
    public var trendSummary: UsageTrendSummary
    
    public init(
        service: ServiceType,
        planName: String = "",
        remainingPercent: Double = 0.0,
        billingDateString: String = "",
        daysUntilBilling: Int = 0,
        status: GaugeStatus = .unknown,
        lastUpdated: Date = Date(),
        isAvailable: Bool = false,
        openCodeWindows: OpenCodeWindows = OpenCodeWindows(),
        googleGroups: GoogleAIGroupLimits = GoogleAIGroupLimits(),
        trendSummary: UsageTrendSummary = UsageTrendSummary()
    ) {
        self.service = service
        self.planName = planName
        self.remainingPercent = remainingPercent
        self.billingDateString = billingDateString
        self.daysUntilBilling = daysUntilBilling
        self.status = status
        self.lastUpdated = lastUpdated
        self.isAvailable = isAvailable
        self.openCodeWindows = openCodeWindows
        self.googleGroups = googleGroups
        self.trendSummary = trendSummary
    }
}

// MARK: - Token & Cost Snapshot (OpenRouter, OpenAI, etc.)
public struct DailyUsagePoint: Identifiable, Sendable {
    public var id: String { dateString }
    public let dateString: String // "2026-11-02"
    public let dateLabel: String  // "11/02"
    public let spendUSD: Double
    public let tokens: Int
    public let normalized: Double // 0.0 to 1.0
    
    public init(
        dateString: String = "",
        dateLabel: String = "",
        spendUSD: Double = 0.0,
        tokens: Int = 0,
        normalized: Double = 0.0
    ) {
        self.dateString = dateString
        self.dateLabel = dateLabel
        self.spendUSD = spendUSD
        self.tokens = tokens
        self.normalized = normalized
    }
}

public enum UsageMetricUnit: String, Sendable {
    case tokens
    case steps
    
    public var label: String {
        switch self {
        case .tokens: return L10n.isKorean ? "토큰" : "tokens"
        case .steps: return L10n.isKorean ? "스텝" : "steps"
        }
    }
    
    public var title: String {
        switch self {
        case .tokens: return L10n.totalTokens
        case .steps: return L10n.isKorean ? "총 스텝" : "Total Steps"
        }
    }
}

public struct UsageTrendSummary: Sendable {
    public var todaySpendUSD: Double
    public var todayTokens: Int
    public var yesterdaySpendUSD: Double
    public var yesterdayTokens: Int
    public var last30DaysSpendUSD: Double
    public var last30DaysTokens: Int
    public var dailyBars: [Double] // 30 values, 0.0 to 1.0
    public var dailyPoints: [DailyUsagePoint]
    
    // Additional metrics & logs to fill vertical space nicely
    public var dailyAvgSpendUSD: Double
    public var dailyAvgTokens: Int
    public var peakDateLabel: String
    public var peakTokens: Int
    public var recentActivityLog: String
    
    // Google AI Pro only exposes step counts (no token/cost API), so its trend
    // reports steps and hides monetary values instead of fabricating them.
    public var metricUnit: UsageMetricUnit
    public var costAvailable: Bool
    
    public init(
        todaySpendUSD: Double = 0.0,
        todayTokens: Int = 0,
        yesterdaySpendUSD: Double = 0.0,
        yesterdayTokens: Int = 0,
        last30DaysSpendUSD: Double = 0.0,
        last30DaysTokens: Int = 0,
        dailyBars: [Double] = [],
        dailyPoints: [DailyUsagePoint] = [],
        dailyAvgSpendUSD: Double = 0.0,
        dailyAvgTokens: Int = 0,
        peakDateLabel: String = "",
        peakTokens: Int = 0,
        recentActivityLog: String = "",
        metricUnit: UsageMetricUnit = .tokens,
        costAvailable: Bool = true
    ) {
        self.todaySpendUSD = todaySpendUSD
        self.todayTokens = todayTokens
        self.yesterdaySpendUSD = yesterdaySpendUSD
        self.yesterdayTokens = yesterdayTokens
        self.last30DaysSpendUSD = last30DaysSpendUSD
        self.last30DaysTokens = last30DaysTokens
        self.dailyBars = dailyBars.isEmpty ? Array(repeating: 0.0, count: 30) : dailyBars
        self.dailyPoints = dailyPoints
        self.dailyAvgSpendUSD = dailyAvgSpendUSD > 0.0 ? dailyAvgSpendUSD : (last30DaysSpendUSD / 30.0)
        self.dailyAvgTokens = dailyAvgTokens > 0 ? dailyAvgTokens : (last30DaysTokens / 30)
        self.peakDateLabel = peakDateLabel
        self.peakTokens = peakTokens
        self.recentActivityLog = recentActivityLog
        self.metricUnit = metricUnit
        self.costAvailable = costAvailable
    }
}

public struct TokenCostSnapshot {
    public var providerId: String
    public var providerName: String
    public var balanceUSD: Double
    public var todaySpendUSD: Double
    public var monthSpendUSD: Double
    public var totalTokens: Int
    public var promptTokens: Int
    public var completionTokens: Int
    public var cachedTokens: Int
    public var requestsCount: Int
    public var status: GaugeStatus
    public var lastUpdated: Date
    public var isConnected: Bool
    public var trendSummary: UsageTrendSummary
    
    public init(
        providerId: String = "openrouter",
        providerName: String = "OpenRouter",
        balanceUSD: Double = 0.0,
        todaySpendUSD: Double = 0.0,
        monthSpendUSD: Double = 0.0,
        totalTokens: Int = 0,
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        cachedTokens: Int = 0,
        requestsCount: Int = 0,
        status: GaugeStatus = .normal,
        lastUpdated: Date = Date(),
        isConnected: Bool = false,
        trendSummary: UsageTrendSummary = UsageTrendSummary()
    ) {
        self.providerId = providerId
        self.providerName = providerName
        self.balanceUSD = balanceUSD
        self.todaySpendUSD = todaySpendUSD
        self.monthSpendUSD = monthSpendUSD
        self.totalTokens = totalTokens
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.cachedTokens = cachedTokens
        self.requestsCount = requestsCount
        self.status = status
        self.lastUpdated = lastUpdated
        self.isConnected = isConnected
        self.trendSummary = trendSummary
    }
}

@MainActor
public final class PopoverUIState: ObservableObject {
    public static let shared = PopoverUIState()
    @Published public var showProviderSettings = false
    @Published public var openRouterKeyInput = ""
    @Published public var isEditingOpenRouterKey = false
    @Published public var showKeySavedToast = false
    @Published public var isEditingGoogleBillingDay = false
    @Published public var selectedBillingDay = 1
    
    // Generic provider key input
    @Published public var genericKeyInput: String = ""
    @Published public var editingProviderKeyId: String? = nil
    
    // Detailed Trend Popover state
    @Published public var selectedTrendTitle: String = ""
    @Published public var selectedTrendSummary: UsageTrendSummary? = nil
    @Published public var showDetailedTrendPopover: Bool = false
    @Published public var hoveredTrendIndex: Int? = nil
}

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    private let defaults = UserDefaults.standard
    
    // 안전한 갱신 주기: 기본 5분(300초), 1분/3분/5분/15분 지원
    @Published public var refreshIntervalSeconds: Double {
        didSet { defaults.set(refreshIntervalSeconds, forKey: "refreshIntervalSeconds") }
    }
    
    @Published public var enabledProviderIds: Set<String> {
        didSet { defaults.set(Array(enabledProviderIds), forKey: "enabledProviderIds") }
    }
    
    @Published public var providerOrder: [String] {
        didSet { defaults.set(providerOrder, forKey: "providerOrder") }
    }
    
    @Published public var selectedTabIndex: Int {
        didSet { defaults.set(selectedTabIndex, forKey: "selectedTabIndex") }
    }
    
    // In-memory key backed by macOS Keychain (절대 평문 노출/역조회 불가)
    @Published public private(set) var openRouterApiKey: String = ""
    
    public var hasOpenRouterKey: Bool {
        return !openRouterApiKey.isEmpty
    }
    
    public func saveOpenRouterKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        self.openRouterApiKey = trimmed
        if trimmed.isEmpty {
            KeychainHelper.shared.delete()
        } else {
            KeychainHelper.shared.save(key: trimmed)
        }
        defaults.removeObject(forKey: "openRouterApiKey") // 평문 제거
        objectWillChange.send()
    }
    
    public func deleteOpenRouterKey() {
        self.openRouterApiKey = ""
        KeychainHelper.shared.delete()
        defaults.removeObject(forKey: "openRouterApiKey")
        setProviderEnabled("openrouter", enabled: false)
        objectWillChange.send()
    }
    
    @Published public var googleBillingDayOfMonth: Int {
        didSet { defaults.set(googleBillingDayOfMonth, forKey: "googleBillingDayOfMonth") }
    }
    
    // 각 카드에서 메뉴바 아이콘으로 표시할 쿼터 기준 (5시간, 주간, 월간)
    @Published public var providerMetricDisplay: [String: String] {
        didSet { defaults.set(providerMetricDisplay, forKey: "providerMetricDisplay") }
    }
    
    // 각 카드에서 메뉴바 아이콘으로 표시할 개별 아이템 키 (예: google_gemini_5h, google_claude_weekly 등)
    @Published public var selectedMetricKeys: [String: String] {
        didSet { defaults.set(selectedMetricKeys, forKey: "selectedMetricKeys") }
    }
    
    public func selectedMetricKey(for providerId: String) -> String {
        if let key = selectedMetricKeys[providerId], !key.isEmpty {
            return key
        }
        if providerId == "opencode" { return "opencode_5h" }
        if providerId == "google_ai" { return "google_gemini_5h" }
        return ""
    }
    
    public func setSelectedMetricKey(for providerId: String, key: String) {
        selectedMetricKeys[providerId] = key
        objectWillChange.send()
        DispatchQueue.main.async {
            UsageManager.shared.onSnapshotUpdated?()
        }
    }
    
    public func metricDisplay(for providerId: String) -> QuotaMetricDisplay {
        if let raw = providerMetricDisplay[providerId], let val = QuotaMetricDisplay(rawValue: raw) {
            return val
        }
        return providerId == "opencode" ? .monthly : .fiveHour
    }
    
    public func setMetricDisplay(for providerId: String, metric: QuotaMetricDisplay) {
        providerMetricDisplay[providerId] = metric.rawValue
        objectWillChange.send()
        DispatchQueue.main.async {
            UsageManager.shared.onSnapshotUpdated?()
        }
    }
    
    public static let defaultPopularityOrder = [
        "codex",
        "claude",
        "cursor",
        "google_ai",
        "opencode",
        "openrouter",
        "copilot",
        "perplexity",
        "deepseek"
    ]
    
    public func saveKey(id: String, key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainHelper.shared.delete(account: "\(id)_api_key")
        } else {
            KeychainHelper.shared.save(key: trimmed, account: "\(id)_api_key")
        }
        setProviderEnabled(id, enabled: !trimmed.isEmpty)
        objectWillChange.send()
    }
    
    public func deleteKey(id: String) {
        KeychainHelper.shared.delete(account: "\(id)_api_key")
        setProviderEnabled(id, enabled: false)
        objectWillChange.send()
    }
    
    public func hasKey(id: String) -> Bool {
        guard let k = KeychainHelper.shared.read(account: "\(id)_api_key") else { return false }
        return !k.isEmpty
    }
    
    private init() {
        let savedInterval = defaults.double(forKey: "refreshIntervalSeconds")
        self.refreshIntervalSeconds = savedInterval >= 60.0 ? savedInterval : 300.0 // 기본 5분
        
        let hasInitialized = defaults.bool(forKey: "hasInitializedProviders_v3")
        if !hasInitialized {
            // 최초 실행 시: 어떤 구독플랜 카드도 기본으로 주어지지 않음. 오직 실제 자동감지된 프로바이더만 추가
            var detected: Set<String> = []
            for pid in Self.defaultPopularityOrder {
                if ProviderDetector.isDetected(id: pid) {
                    detected.insert(pid)
                }
            }
            self.enabledProviderIds = detected
            defaults.set(Array(detected), forKey: "enabledProviderIds")
            defaults.set(true, forKey: "hasInitializedProviders_v3")
        } else if let savedIds = defaults.stringArray(forKey: "enabledProviderIds") {
            self.enabledProviderIds = Set(savedIds)
        } else {
            self.enabledProviderIds = []
        }
        
        if let savedOrder = defaults.stringArray(forKey: "providerOrder"), !savedOrder.isEmpty {
            var merged = savedOrder
            for def in Self.defaultPopularityOrder where !merged.contains(def) {
                merged.append(def)
            }
            self.providerOrder = merged
        } else {
            self.providerOrder = Self.defaultPopularityOrder
        }
        
        self.selectedTabIndex = defaults.integer(forKey: "selectedTabIndex")
        
        // Keychain에서 보안 로드 (legacy UserDefaults 이전 지원)
        if let kcKey = KeychainHelper.shared.read(), !kcKey.isEmpty {
            self.openRouterApiKey = kcKey
        } else if let legacyKey = defaults.string(forKey: "openRouterApiKey"), !legacyKey.isEmpty {
            KeychainHelper.shared.save(key: legacyKey)
            defaults.removeObject(forKey: "openRouterApiKey")
            self.openRouterApiKey = legacyKey
        } else {
            self.openRouterApiKey = ""
        }
        
        self.googleBillingDayOfMonth = defaults.integer(forKey: "googleBillingDayOfMonth")
        self.providerMetricDisplay = defaults.dictionary(forKey: "providerMetricDisplay") as? [String: String] ?? [:]
        self.selectedMetricKeys = defaults.dictionary(forKey: "selectedMetricKeys") as? [String: String] ?? [:]
    }
    
    public func moveProviderUp(id: String) {
        guard let idx = providerOrder.firstIndex(of: id), idx > 0 else { return }
        providerOrder.swapAt(idx, idx - 1)
        objectWillChange.send()
        DispatchQueue.main.async {
            UsageManager.shared.onSnapshotUpdated?()
        }
    }
    
    public func moveProviderDown(id: String) {
        guard let idx = providerOrder.firstIndex(of: id), idx < providerOrder.count - 1 else { return }
        providerOrder.swapAt(idx, idx + 1)
        objectWillChange.send()
        DispatchQueue.main.async {
            UsageManager.shared.onSnapshotUpdated?()
        }
    }
    
    public func isProviderEnabled(_ id: String) -> Bool {
        enabledProviderIds.contains(id)
    }
    
    public func setProviderEnabled(_ id: String, enabled: Bool) {
        if enabled {
            enabledProviderIds.insert(id)
        } else {
            enabledProviderIds.remove(id)
        }
    }
}
