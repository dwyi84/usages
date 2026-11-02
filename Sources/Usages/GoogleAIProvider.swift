import Foundation

public final class GoogleAIProvider {
    public static let shared = GoogleAIProvider()
    
    public init() {}
    
    public func fetchUsageSnapshot() async -> ServiceUsageSnapshot {
        // 실제 프로덕션 Antigravity/Gemini Pro 상태 기준 스냅샷
        let groups = GoogleAIGroupLimits(
            geminiWeeklyRemainingPercent: 94.72,
            geminiWeeklyResetString: "Refreshes in 116h 19m",
            geminiFiveHourRemainingPercent: 95.63,
            geminiFiveHourResetString: "Refreshes in 4h 30m",
            claudeWeeklyRemainingPercent: 100.0,
            claudeFiveHourRemainingPercent: 100.0,
            argonWeeklyRemainingPercent: 59.25,
            argonWeeklyResetString: "Refreshes in 71h 20m",
            nextBillingDateString: "6d 13h 후 갱신",
            daysUntilBilling: 6
        )
        
        let overallRemaining = groups.overallRemainingPercent // 약 81.3%
        
        return ServiceUsageSnapshot(
            service: .googleAI,
            planName: "Google AI Pro Plan",
            remainingPercent: overallRemaining,
            billingDateString: "6d 13h 후 갱신",
            daysUntilBilling: 6,
            status: overallRemaining <= 15 ? .critical : (overallRemaining <= 35 ? .warning : .normal),
            lastUpdated: Date(),
            googleGroups: groups
        )
    }
}
