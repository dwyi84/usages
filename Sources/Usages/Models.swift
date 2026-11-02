import Foundation
import SwiftUI

public enum ServiceType: String, Codable, CaseIterable {
    case openCode = "OpenCode Go"
    case googleAI = "Google AI Pro"
}

public enum GaugeStatus {
    case normal
    case warning
    case critical
    case error
    case unknown
    
    public var color: Color {
        switch self {
        case .normal: return Color.green
        case .warning: return Color.orange
        case .critical: return Color.red
        case .error: return Color.gray
        case .unknown: return Color.secondary
        }
    }
}

// MARK: - OpenCode Go Detail Windows (실제 구조: 5h, Weekly, Monthly)
public struct OpenCodeWindows {
    public var fiveHourRemainingPercent: Double = 95.0   // 5% used -> 95% remaining
    public var fiveHourResetString: String = "Resets in 3h 37m"
    
    public var weeklyRemainingPercent: Double = 98.0     // 2% used -> 98% remaining
    public var weeklyResetString: String = "Resets in 6d 15h"
    
    public var monthlyRemainingPercent: Double = 36.0    // 64% used -> 36% remaining
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

// MARK: - Google AI Pro Detail Groups (실제 구조: Gemini, Claude & GPT, Argon)
public struct GoogleAIGroupLimits {
    // 1. GEMINI MODELS (Gemini Flash, Gemini Pro)
    public var geminiWeeklyRemainingPercent: Double = 94.72
    public var geminiWeeklyResetString: String = "Refreshes in 116h 19m"
    public var geminiFiveHourRemainingPercent: Double = 95.63
    public var geminiFiveHourResetString: String = "Refreshes in 4h 30m"
    
    // 2. CLAUDE AND GPT MODELS (Claude Opus, Claude Sonnet, GPT-OSS)
    public var claudeWeeklyRemainingPercent: Double = 100.0
    public var claudeFiveHourRemainingPercent: Double = 100.0
    
    // 3. GEMINI 4 ARGON (Argon quota is separate)
    public var argonWeeklyRemainingPercent: Double = 59.25
    public var argonWeeklyResetString: String = "Refreshes in 71h 20m"
    
    // 종합 잔여율 (메인 툴바 아이콘용)
    public var overallRemainingPercent: Double {
        // 가중 평균: Argon(40%) + Gemini(40%) + Claude(20%)
        return (argonWeeklyRemainingPercent * 0.40) + (geminiWeeklyRemainingPercent * 0.40) + (claudeWeeklyRemainingPercent * 0.20)
    }
    
    public var nextBillingDateString: String = "D-6일 후 갱신"
    public var daysUntilBilling: Int = 6
    
    public init(
        geminiWeeklyRemainingPercent: Double = 94.72,
        geminiWeeklyResetString: String = "Refreshes in 116h 19m",
        geminiFiveHourRemainingPercent: Double = 95.63,
        geminiFiveHourResetString: String = "Refreshes in 4h 30m",
        claudeWeeklyRemainingPercent: Double = 100.0,
        claudeFiveHourRemainingPercent: Double = 100.0,
        argonWeeklyRemainingPercent: Double = 59.25,
        argonWeeklyResetString: String = "Refreshes in 71h 20m",
        nextBillingDateString: String = "D-6일 후 갱신",
        daysUntilBilling: Int = 6
    ) {
        self.geminiWeeklyRemainingPercent = geminiWeeklyRemainingPercent
        self.geminiWeeklyResetString = geminiWeeklyResetString
        self.geminiFiveHourRemainingPercent = geminiFiveHourRemainingPercent
        self.geminiFiveHourResetString = geminiFiveHourResetString
        self.claudeWeeklyRemainingPercent = claudeWeeklyRemainingPercent
        self.claudeFiveHourRemainingPercent = claudeFiveHourRemainingPercent
        self.argonWeeklyRemainingPercent = argonWeeklyRemainingPercent
        self.argonWeeklyResetString = argonWeeklyResetString
        self.nextBillingDateString = nextBillingDateString
        self.daysUntilBilling = daysUntilBilling
    }
}

public struct ServiceUsageSnapshot {
    public var service: ServiceType
    public var planName: String
    public var remainingPercent: Double // 툴바 게이지에 쓸 대표 잔여량 (0~100)
    public var usedPercent: Double {
        max(0.0, min(100.0, 100.0 - remainingPercent))
    }
    public var billingDateString: String
    public var daysUntilBilling: Int
    public var status: GaugeStatus
    public var lastUpdated: Date
    
    // Windows & Categories
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
        self.openCodeWindows = openCodeWindows
        self.googleGroups = googleGroups
    }
}

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    private let defaults = UserDefaults.standard
    
    @Published public var refreshIntervalSeconds: Double {
        didSet { defaults.set(refreshIntervalSeconds, forKey: "refreshIntervalSeconds") }
    }
    
    private init() {
        self.refreshIntervalSeconds = defaults.double(forKey: "refreshIntervalSeconds") > 0 ? defaults.double(forKey: "refreshIntervalSeconds") : 30.0
    }
}
