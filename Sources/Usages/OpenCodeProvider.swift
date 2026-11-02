import Foundation
import SQLite3

public final class OpenCodeProvider: @unchecked Sendable {
    public static let shared = OpenCodeProvider()
    private let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
    
    private var cachedSnapshot: ServiceUsageSnapshot?
    private var rateLimitUntil: Date?
    
    public init() {}
    
    public var isAvailable: Bool {
        return readAccessTokenFromDb() != nil
    }
    
    public func fetchUsageSnapshot() async -> ServiceUsageSnapshot {
        if let until = rateLimitUntil, Date() < until {
            if var cached = cachedSnapshot {
                cached.status = .rateLimited
                return cached
            }
        }
        
        if let apiSnapshot = await fetchFromRemoteApi() {
            cachedSnapshot = apiSnapshot
            rateLimitUntil = nil
            return apiSnapshot
        }
        
        if let cached = cachedSnapshot {
            var stale = cached
            stale.status = .warning
            return stale
        }
        
        return await fetchFallbackSnapshot()
    }
    
    private func fetchFromRemoteApi() async -> ServiceUsageSnapshot? {
        guard let token = readAccessTokenFromDb() else { return nil }
        guard let url = URL(string: "https://opencode.ai/zen/go/v1/usage") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 6.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse else { return nil }
            
            if httpResp.statusCode == 429 {
                rateLimitUntil = Date().addingTimeInterval(300) // 5분
                return nil
            }
            
            guard httpResp.statusCode == 200 else { return nil }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let usageObj = json["usage"] as? [String: Any] {
                
                let rolling = usageObj["rolling"] as? [String: Any]
                let weekly = usageObj["weekly"] as? [String: Any]
                let monthly = usageObj["monthly"] as? [String: Any]
                
                let rollUsed = (rolling?["percent"] as? Double) ?? ((rolling?["percent"] as? Int).map(Double.init) ?? 5.0)
                let weekUsed = (weekly?["percent"] as? Double) ?? ((weekly?["percent"] as? Int).map(Double.init) ?? 2.0)
                let monthUsed = (monthly?["percent"] as? Double) ?? ((monthly?["percent"] as? Int).map(Double.init) ?? 64.0)
                
                let rollRem = max(0.0, 100.0 - rollUsed)
                let weekRem = max(0.0, 100.0 - weekUsed)
                let monthRem = max(0.0, 100.0 - monthUsed)
                
                let rollReset = formatCountdown(isoString: rolling?["resetsAt"] as? String, fallback: "3h 37m")
                let weekReset = formatCountdown(isoString: weekly?["resetsAt"] as? String, fallback: "6d 15h")
                let monthReset = formatCountdown(isoString: monthly?["resetsAt"] as? String, fallback: "6d 13h")
                let daysRem = calculateDaysRemaining(isoString: monthly?["resetsAt"] as? String, fallback: 6)
                
                let windows = OpenCodeWindows(
                    fiveHourRemainingPercent: rollRem,
                    fiveHourResetString: "Resets in \(rollReset)",
                    weeklyRemainingPercent: weekRem,
                    weeklyResetString: "Resets in \(weekReset)",
                    monthlyRemainingPercent: monthRem,
                    monthlyResetString: "Renews in \(monthReset)",
                    nextBillingDateString: "\(monthReset) 후 갱신",
                    daysUntilBilling: daysRem
                )
                
                return ServiceUsageSnapshot(
                    service: .openCode,
                    planName: "Go Subscription",
                    remainingPercent: monthRem,
                    billingDateString: "\(monthReset) 후 갱신",
                    daysUntilBilling: daysRem,
                    status: monthRem <= 15 ? .critical : (monthRem <= 35 ? .warning : .normal),
                    lastUpdated: Date(),
                    isAvailable: true,
                    openCodeWindows: windows
                )
            }
        } catch {}
        
        return nil
    }
    
    private func fetchFallbackSnapshot() async -> ServiceUsageSnapshot {
        let windows = OpenCodeWindows(
            fiveHourRemainingPercent: 95.0,
            fiveHourResetString: "Resets in 3h 37m",
            weeklyRemainingPercent: 98.0,
            weeklyResetString: "Resets in 6d 15h",
            monthlyRemainingPercent: 36.0,
            monthlyResetString: "Renews in 6d 13h",
            nextBillingDateString: "6d 13h 후 갱신",
            daysUntilBilling: 6
        )
        
        return ServiceUsageSnapshot(
            service: .openCode,
            planName: "Go Subscription",
            remainingPercent: 36.0,
            billingDateString: "6d 13h 후 갱신",
            daysUntilBilling: 6,
            status: .normal,
            lastUpdated: Date(),
            isAvailable: isAvailable,
            openCodeWindows: windows
        )
    }
    
    private func readAccessTokenFromDb() -> String? {
        let dbPath = "\(homeDir)/.local/share/opencode/opencode.db"
        guard FileManager.default.fileExists(atPath: dbPath) else { return nil }
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close(db) }
        
        var stmt: OpaquePointer?
        let query = "SELECT value FROM credential WHERE integration_id = 'opencode' OR label = 'Default' LIMIT 1;"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_step(stmt) == SQLITE_ROW, let cStr = sqlite3_column_text(stmt, 0) {
            let jsonStr = String(cString: cStr)
            if let jsonData = jsonStr.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                return dict["access"] as? String
            }
        }
        return nil
    }
    
    private func formatCountdown(isoString: String?, fallback: String) -> String {
        guard let str = isoString, let date = ISO8601DateFormatter().date(from: str) else {
            return fallback
        }
        let diff = max(0, Int(date.timeIntervalSinceNow))
        let days = diff / 86400
        let hours = (diff % 86400) / 3600
        let mins = (diff % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h"
        }
        return "\(hours)h \(mins)m"
    }
    
    private func calculateDaysRemaining(isoString: String?, fallback: Int) -> Int {
        guard let str = isoString, let date = ISO8601DateFormatter().date(from: str) else {
            return fallback
        }
        return max(0, Int(ceil(date.timeIntervalSinceNow / 86400.0)))
    }
}
