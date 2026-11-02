import Foundation
import SwiftUI

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
    
    public var nextBillingDateString: String = "6d 13h 후 자동 갱신"
    public var daysUntilBilling: Int = 6
    
    public init(
        fiveHourRemainingPercent: Double = 95.0,
        fiveHourResetString: String = "Resets in 3h 37m",
        weeklyRemainingPercent: Double = 98.0,
        weeklyResetString: String = "Resets in 6d 15h",
        monthlyRemainingPercent: Double = 36.0,
        monthlyResetString: String = "Renews in 6d 13h",
        nextBillingDateString: String = "6d 13h 후 자동 갱신",
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
    public var geminiWeeklyResetString: String = "Refreshes in 115h 45m"
    public var geminiFiveHourRemainingPercent: Double = 90.73
    public var geminiFiveHourResetString: String = "Refreshes in 3h 56m"
    
    public var claudeWeeklyRemainingPercent: Double = 100.0
    public var claudeWeeklyResetString: String = "Quota available"
    public var claudeFiveHourRemainingPercent: Double = 100.0
    public var claudeFiveHourResetString: String = "Quota available"
    
    public var argonWeeklyRemainingPercent: Double = 59.25
    public var argonWeeklyResetString: String = "Refreshes in 70h 46m"
    
    public var overallRemainingPercent: Double {
        return min(argonWeeklyRemainingPercent, geminiWeeklyRemainingPercent)
    }
    
    public var nextBillingDateString: String = "D-6일 후 갱신"
    public var daysUntilBilling: Int = 6
    
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
        nextBillingDateString: String = "D-6일 후 갱신",
        daysUntilBilling: Int = 6
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
        googleGroups: GoogleAIGroupLimits = GoogleAIGroupLimits()
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
    }
}

// MARK: - Token & Cost Snapshot (OpenRouter, OpenAI, etc.)
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
        isConnected: Bool = false
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
    }
}

@MainActor
public final class PopoverUIState: ObservableObject {
    public static let shared = PopoverUIState()
    @Published public var showProviderSettings = false
    @Published public var openRouterKeyInput = ""
    @Published public var showKeySavedToast = false
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
    
    @Published public var selectedTabIndex: Int {
        didSet { defaults.set(selectedTabIndex, forKey: "selectedTabIndex") }
    }
    
    @Published public var openRouterApiKey: String {
        didSet { defaults.set(openRouterApiKey, forKey: "openRouterApiKey") }
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
        
        self.selectedTabIndex = defaults.integer(forKey: "selectedTabIndex")
        self.openRouterApiKey = defaults.string(forKey: "openRouterApiKey") ?? ""
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
