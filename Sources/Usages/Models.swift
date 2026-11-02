import Foundation
import SwiftUI

public enum ServiceType: String, Codable, CaseIterable {
    case openCode = "OpenCode Go"
    case googleAI = "Google AI Pro"
    
    public var shortLabel: String {
        switch self {
        case .openCode: return "OC"
        case .googleAI: return "G"
        }
    }
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
    
    public var nsColor: NSColor {
        switch self {
        case .normal: return NSColor.systemGreen
        case .warning: return NSColor.systemOrange
        case .critical: return NSColor.systemRed
        case .error: return NSColor.systemGray
        case .unknown: return NSColor.secondaryLabelColor
        }
    }
}

public struct ModelUsageItem: Identifiable, Codable {
    public var id: String { name }
    public let name: String
    public let provider: String
    public let steps: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let reasoningTokens: Int
    public let cost: Double
    
    public var totalTokens: Int {
        inputTokens + outputTokens + reasoningTokens
    }
}

// MARK: - OpenCode Go Detail Windows
public struct OpenCodeWindows {
    public var rollingPercent: Double = 0.0     // 5시간 롤링
    public var rollingResetString: String = ""
    public var weeklyPercent: Double = 0.0      // 주간 한도
    public var weeklyResetString: String = ""
    public var monthlyPercent: Double = 0.0     // 월간 쿼터
    public var monthlyResetString: String = ""
    public var daysUntilReset: Int = 0          // 갱신일까지 남은 일수
    
    public init(
        rollingPercent: Double = 0.0,
        rollingResetString: String = "",
        weeklyPercent: Double = 0.0,
        weeklyResetString: String = "",
        monthlyPercent: Double = 0.0,
        monthlyResetString: String = "",
        daysUntilReset: Int = 0
    ) {
        self.rollingPercent = rollingPercent
        self.rollingResetString = rollingResetString
        self.weeklyPercent = weeklyPercent
        self.weeklyResetString = weeklyResetString
        self.monthlyPercent = monthlyPercent
        self.monthlyResetString = monthlyResetString
        self.daysUntilReset = daysUntilReset
    }
}

// MARK: - Google AI Pro Detail Categories
public struct GoogleAICategories {
    public var firstPartyPercent: Double = 0.0    // 자사 모델 (Gemini Flash 등)
    public var firstPartyUsed: Int = 0
    public var firstPartyLimit: Int = 1500
    
    public var argonPercent: Double = 0.0         // 아르곤 (Gemini 4 Argon)
    public var argonUsed: Int = 0
    public var argonLimit: Int = 500
    
    public var thirdPartyPercent: Double = 0.0    // 타사 모델 (Claude Sonnet/Opus 등)
    public var thirdPartyUsed: Int = 0
    public var thirdPartyLimit: Int = 200
    
    public var monthlyPercent: Double = 0.0       // 월간 종합 사용률
    public var daysUntilReset: Int = 0            // 갱신일까지 남은 일수
    public var resetTimeString: String = ""
    
    public init(
        firstPartyPercent: Double = 0.0,
        firstPartyUsed: Int = 0,
        firstPartyLimit: Int = 1500,
        argonPercent: Double = 0.0,
        argonUsed: Int = 0,
        argonLimit: Int = 500,
        thirdPartyPercent: Double = 0.0,
        thirdPartyUsed: Int = 0,
        thirdPartyLimit: Int = 200,
        monthlyPercent: Double = 0.0,
        daysUntilReset: Int = 0,
        resetTimeString: String = ""
    ) {
        self.firstPartyPercent = firstPartyPercent
        self.firstPartyUsed = firstPartyUsed
        self.firstPartyLimit = firstPartyLimit
        self.argonPercent = argonPercent
        self.argonUsed = argonUsed
        self.argonLimit = argonLimit
        self.thirdPartyPercent = thirdPartyPercent
        self.thirdPartyUsed = thirdPartyUsed
        self.thirdPartyLimit = thirdPartyLimit
        self.monthlyPercent = monthlyPercent
        self.daysUntilReset = daysUntilReset
        self.resetTimeString = resetTimeString
    }
}

public struct ServiceUsageSnapshot {
    public var service: ServiceType
    public var planName: String
    public var usedPercent: Double       // 메인 게이지에 쓸 월간 사용률 (0~100)
    public var remainingPercent: Double {
        max(0.0, min(100.0, 100.0 - usedPercent))
    }
    public var currentUsed: Double
    public var maxLimit: Double
    public var unit: String
    public var resetTimeString: String
    public var daysUntilReset: Int       // 갱신일까지 남은 일수
    public var status: GaugeStatus
    public var statusMessage: String
    public var lastUpdated: Date
    public var modelBreakdowns: [ModelUsageItem]
    
    // Windows & Categories
    public var openCodeWindows: OpenCodeWindows
    public var googleCategories: GoogleAICategories
    
    // General metrics
    public var todayTokens: Int
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadTokens: Int
    public var todayCost: Double
    public var sessionCount: Int
    public var todaySteps: Int
    
    public init(
        service: ServiceType,
        planName: String = "",
        usedPercent: Double = 0.0,
        currentUsed: Double = 0.0,
        maxLimit: Double = 100.0,
        unit: String = "%",
        resetTimeString: String = "",
        daysUntilReset: Int = 0,
        status: GaugeStatus = .normal,
        statusMessage: String = "",
        lastUpdated: Date = Date(),
        modelBreakdowns: [ModelUsageItem] = [],
        openCodeWindows: OpenCodeWindows = OpenCodeWindows(),
        googleCategories: GoogleAICategories = GoogleAICategories(),
        todayTokens: Int = 0,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheReadTokens: Int = 0,
        todayCost: Double = 0.0,
        sessionCount: Int = 0,
        todaySteps: Int = 0
    ) {
        self.service = service
        self.planName = planName
        self.usedPercent = usedPercent
        self.currentUsed = currentUsed
        self.maxLimit = maxLimit
        self.unit = unit
        self.resetTimeString = resetTimeString
        self.daysUntilReset = daysUntilReset
        self.status = status
        self.statusMessage = statusMessage
        self.lastUpdated = lastUpdated
        self.modelBreakdowns = modelBreakdowns
        self.openCodeWindows = openCodeWindows
        self.googleCategories = googleCategories
        self.todayTokens = todayTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.todayCost = todayCost
        self.sessionCount = sessionCount
        self.todaySteps = todaySteps
    }
}

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    private let defaults = UserDefaults.standard
    
    @Published public var refreshIntervalSeconds: Double {
        didSet { defaults.set(refreshIntervalSeconds, forKey: "refreshIntervalSeconds") }
    }
    
    @Published public var googleApiKey: String {
        didSet { defaults.set(googleApiKey, forKey: "googleApiKey") }
    }
    
    @Published public var openCodeApiKey: String {
        didSet { defaults.set(openCodeApiKey, forKey: "openCodeApiKey") }
    }
    
    private init() {
        self.refreshIntervalSeconds = defaults.double(forKey: "refreshIntervalSeconds") > 0 ? defaults.double(forKey: "refreshIntervalSeconds") : 30.0
        self.googleApiKey = defaults.string(forKey: "googleApiKey") ?? ""
        self.openCodeApiKey = defaults.string(forKey: "openCodeApiKey") ?? ""
    }
}
