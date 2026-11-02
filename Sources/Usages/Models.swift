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
    
    public var defaultIconName: String {
        switch self {
        case .openCode: return "cpu"
        case .googleAI: return "sparkles"
        }
    }
}

public enum GaugeStatus {
    case normal      // 0 ~ 70% used (or > 30% remaining)
    case warning     // 70 ~ 90% used
    case critical    // > 90% used
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

public struct ServiceUsageSnapshot {
    public var service: ServiceType
    public var planName: String
    public var usedPercent: Double       // 0.0 ~ 100.0 (예: 25.0 = 25% 사용됨)
    public var remainingPercent: Double {
        max(0.0, min(100.0, 100.0 - usedPercent))
    }
    public var currentUsed: Double
    public var maxLimit: Double
    public var unit: String
    public var resetTimeString: String
    public var status: GaugeStatus
    public var statusMessage: String
    public var lastUpdated: Date
    public var modelBreakdowns: [ModelUsageItem]
    
    // Additional metrics
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
        resetTimeString: String = "일일 자동 리셋",
        status: GaugeStatus = .normal,
        statusMessage: String = "정상",
        lastUpdated: Date = Date(),
        modelBreakdowns: [ModelUsageItem] = [],
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
        self.status = status
        self.statusMessage = statusMessage
        self.lastUpdated = lastUpdated
        self.modelBreakdowns = modelBreakdowns
        self.todayTokens = todayTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.todayCost = todayCost
        self.sessionCount = sessionCount
        self.todaySteps = todaySteps
    }
}

public enum MenuBarDisplayMode: String, Codable, CaseIterable {
    case separateItems = "개별 배터리 아이콘 (OC / Google 각각)"
    case combinedItem = "통합 단일 아이콘 ([OC] [G])"
}

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    @Published public var displayMode: MenuBarDisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: "displayMode") }
    }
    
    @Published public var showPercentText: Bool {
        didSet { defaults.set(showPercentText, forKey: "showPercentText") }
    }
    
    @Published public var showShortLabel: Bool {
        didSet { defaults.set(showShortLabel, forKey: "showShortLabel") }
    }
    
    @Published public var refreshIntervalSeconds: Double {
        didSet { defaults.set(refreshIntervalSeconds, forKey: "refreshIntervalSeconds") }
    }
    
    @Published public var googleApiKey: String {
        didSet { defaults.set(googleApiKey, forKey: "googleApiKey") }
    }
    
    @Published public var openCodeApiKey: String {
        didSet { defaults.set(openCodeApiKey, forKey: "openCodeApiKey") }
    }
    
    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    
    private init() {
        if let modeRaw = defaults.string(forKey: "displayMode"),
           let mode = MenuBarDisplayMode(rawValue: modeRaw) {
            self.displayMode = mode
        } else {
            self.displayMode = .separateItems
        }
        
        self.showPercentText = defaults.object(forKey: "showPercentText") != nil ? defaults.bool(forKey: "showPercentText") : true
        self.showShortLabel = defaults.object(forKey: "showShortLabel") != nil ? defaults.bool(forKey: "showShortLabel") : true
        self.refreshIntervalSeconds = defaults.double(forKey: "refreshIntervalSeconds") > 0 ? defaults.double(forKey: "refreshIntervalSeconds") : 30.0
        self.googleApiKey = defaults.string(forKey: "googleApiKey") ?? ""
        self.openCodeApiKey = defaults.string(forKey: "openCodeApiKey") ?? ""
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    }
}
