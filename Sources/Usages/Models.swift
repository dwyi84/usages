import Foundation
import SwiftUI
import Security

// MARK: - Native macOS Keychain Helper for Secure Credentials
public final class KeychainHelper {
    public static let shared = KeychainHelper()
    private let service = "com.melissasoft.aiusages"
    private let account = "openrouter_api_key"
    
    public func save(key: String) {
        guard let data = key.data(using: .utf8) else { return }
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    public func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
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
    
    public func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public enum ServiceType: String, Codable, CaseIterable {
    case openCode = "OpenCode Go"
    case googleAI = "Google AI Pro"
    case openRouter = "OpenRouter"
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
    public var fiveHourRemainingPercent: Double = 95.0
    public var fiveHourResetString: String = "Resets in 3h 37m"
    
    public var weeklyRemainingPercent: Double = 98.0
    public var weeklyResetString: String = "Resets in 6d 15h"
    
    public var monthlyRemainingPercent: Double = 36.0
    public var monthlyResetString: String = "Renews in 6d 13h"
    
    public var nextBillingDateString: String = "6일 13시간 후 리셋"
    public var daysUntilBilling: Int = 6
    
    public init(
        fiveHourRemainingPercent: Double = 95.0,
        fiveHourResetString: String = "3시간 37분 후 리셋",
        weeklyRemainingPercent: Double = 98.0,
        weeklyResetString: String = "6일 15시간 후 리셋",
        monthlyRemainingPercent: Double = 36.0,
        monthlyResetString: String = "6일 13시간 후 리셋",
        nextBillingDateString: String = "6일 13시간 후 리셋",
        daysUntilBilling: Int = 6
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
public struct GoogleAIGroupLimits {
    public var geminiWeeklyRemainingPercent: Double = 93.52
    public var geminiWeeklyResetString: String = L10n.isKorean ? "115시간 45분 후 초기화" : "Refreshes in 115h 45m"
    public var geminiFiveHourRemainingPercent: Double = 90.73
    public var geminiFiveHourResetString: String = L10n.isKorean ? "3시간 56분 후 초기화" : "Refreshes in 3h 56m"
    
    public var claudeWeeklyRemainingPercent: Double = 100.0
    public var claudeWeeklyResetString: String = L10n.quotaAvailable
    public var claudeFiveHourRemainingPercent: Double = 100.0
    public var claudeFiveHourResetString: String = L10n.quotaAvailable
    
    public var argonWeeklyRemainingPercent: Double = 59.25
    public var argonWeeklyResetString: String = L10n.isKorean ? "70시간 46분 후 초기화" : "Refreshes in 70h 46m"
    
    public var overallRemainingPercent: Double {
        return min(argonWeeklyRemainingPercent, geminiWeeklyRemainingPercent)
    }
    
    public var nextBillingDateString: String = ""
    public var daysUntilBilling: Int = 0
    
    public init(
        geminiWeeklyRemainingPercent: Double = 93.52,
        geminiWeeklyResetString: String = "Refreshes in 115h 45m",
        geminiFiveHourRemainingPercent: Double = 90.73,
        geminiFiveHourResetString: String = "Refreshes in 3h 56m",
        claudeWeeklyRemainingPercent: Double = 100.0,
        claudeWeeklyResetString: String = "Quota available",
        claudeFiveHourRemainingPercent: Double = 100.0,
        claudeFiveHourResetString: String = "Quota available",
        argonWeeklyRemainingPercent: Double = 59.25,
        argonWeeklyResetString: String = "Refreshes in 70h 46m",
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
        remainingPercent: Double = 100.0,
        billingDateString: String = "",
        daysUntilBilling: Int = 6,
        status: GaugeStatus = .normal,
        lastUpdated: Date = Date(),
        isAvailable: Bool = true,
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

public struct UsageTrendSummary: Sendable {
    public var todaySpendUSD: Double
    public var todayTokens: Int
    public var yesterdaySpendUSD: Double
    public var yesterdayTokens: Int
    public var last30DaysSpendUSD: Double
    public var last30DaysTokens: Int
    public var dailyBars: [Double] // 30 values, 0.0 to 1.0
    public var dailyPoints: [DailyUsagePoint]
    
    public init(
        todaySpendUSD: Double = 0.0,
        todayTokens: Int = 0,
        yesterdaySpendUSD: Double = 0.0,
        yesterdayTokens: Int = 0,
        last30DaysSpendUSD: Double = 0.0,
        last30DaysTokens: Int = 0,
        dailyBars: [Double] = [],
        dailyPoints: [DailyUsagePoint] = []
    ) {
        self.todaySpendUSD = todaySpendUSD
        self.todayTokens = todayTokens
        self.yesterdaySpendUSD = yesterdaySpendUSD
        self.yesterdayTokens = yesterdayTokens
        self.last30DaysSpendUSD = last30DaysSpendUSD
        self.last30DaysTokens = last30DaysTokens
        self.dailyBars = dailyBars.isEmpty ? Array(repeating: 0.0, count: 30) : dailyBars
        self.dailyPoints = dailyPoints
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
    
    private init() {
        let savedInterval = defaults.double(forKey: "refreshIntervalSeconds")
        self.refreshIntervalSeconds = savedInterval >= 60.0 ? savedInterval : 300.0 // 기본 5분
        
        if let savedIds = defaults.stringArray(forKey: "enabledProviderIds") {
            self.enabledProviderIds = Set(savedIds)
        } else {
            // 기본값: OpenCode 및 Google AI 활성화
            self.enabledProviderIds = ["opencode", "google_ai"]
        }
        
        let defaultOrder = ["opencode", "google_ai", "openrouter"]
        if let savedOrder = defaults.stringArray(forKey: "providerOrder"), !savedOrder.isEmpty {
            var merged = savedOrder
            for def in defaultOrder where !merged.contains(def) {
                merged.append(def)
            }
            self.providerOrder = merged
        } else {
            self.providerOrder = defaultOrder
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
