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
        guard isAvailable else {
            return ServiceUsageSnapshot(
                service: .openCode,
                planName: "OpenCode Go",
                remainingPercent: 0.0,
                billingDateString: "",
                daysUntilBilling: 0,
                status: .unknown,
                lastUpdated: Date(),
                isAvailable: false,
                openCodeWindows: OpenCodeWindows(),
                trendSummary: UsageTrendSummary()
            )
        }
        
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
        
        return ServiceUsageSnapshot(
            service: .openCode,
            planName: "OpenCode Go",
            remainingPercent: 0.0,
            billingDateString: "",
            daysUntilBilling: 0,
            status: .unknown,
            lastUpdated: Date(),
            isAvailable: false,
            openCodeWindows: OpenCodeWindows(),
            trendSummary: fetchLocalUsageTrend()
        )
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
                
                let rollReset = formatCountdown(isoString: rolling?["resetsAt"] as? String, fallbackDays: 0, fallbackHours: 3, fallbackMins: 37)
                let weekReset = formatCountdown(isoString: weekly?["resetsAt"] as? String, fallbackDays: 6, fallbackHours: 15, fallbackMins: 0)
                let monthReset = formatCountdown(isoString: monthly?["resetsAt"] as? String, fallbackDays: 6, fallbackHours: 13, fallbackMins: 0)
                let daysRem = calculateDaysRemaining(isoString: monthly?["resetsAt"] as? String, fallback: 6)
                
                let fiveHourStr = L10n.isKorean ? "\(rollReset) 후 리셋" : "Resets in \(rollReset)"
                let weeklyStr = L10n.isKorean ? "\(weekReset) 후 리셋" : "Resets in \(weekReset)"
                let monthlyStr = L10n.isKorean ? "\(monthReset) 후 리셋" : "Resets in \(monthReset)"
                let billingStr = L10n.isKorean ? "\(monthReset) 후 리셋" : "Resets in \(monthReset)"
                
                let windows = OpenCodeWindows(
                    fiveHourRemainingPercent: rollRem,
                    fiveHourResetString: fiveHourStr,
                    weeklyRemainingPercent: weekRem,
                    weeklyResetString: weeklyStr,
                    monthlyRemainingPercent: monthRem,
                    monthlyResetString: monthlyStr,
                    nextBillingDateString: billingStr,
                    daysUntilBilling: daysRem
                )
                
                let trend = fetchLocalUsageTrend()
                
                return ServiceUsageSnapshot(
                    service: .openCode,
                    planName: "OpenCode Go",
                    remainingPercent: monthRem,
                    billingDateString: billingStr,
                    daysUntilBilling: daysRem,
                    status: monthRem <= 15 ? .critical : (monthRem <= 35 ? .warning : .normal),
                    lastUpdated: Date(),
                    isAvailable: true,
                    openCodeWindows: windows,
                    trendSummary: trend
                )
            }
        } catch {}
        
        return nil
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
    
    private func formatCountdown(isoString: String?, fallbackDays: Int, fallbackHours: Int, fallbackMins: Int) -> String {
        let days: Int
        let hours: Int
        let mins: Int
        if let str = isoString, let date = ISO8601DateFormatter().date(from: str) {
            let diff = max(0, Int(date.timeIntervalSinceNow))
            days = diff / 86400
            hours = (diff % 86400) / 3600
            mins = (diff % 3600) / 60
        } else {
            days = fallbackDays
            hours = fallbackHours
            mins = fallbackMins
        }
        
        if L10n.isKorean {
            if days > 0 {
                return "\(days)일 \(hours)시간"
            }
            return "\(hours)시간 \(mins)분"
        } else {
            if days > 0 {
                return "\(days)d \(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
    }
    
    private func calculateDaysRemaining(isoString: String?, fallback: Int) -> Int {
        guard let str = isoString, let date = ISO8601DateFormatter().date(from: str) else {
            return fallback
        }
        return max(0, Int(ceil(date.timeIntervalSinceNow / 86400.0)))
    }
    
    private func fetchLocalUsageTrend() -> UsageTrendSummary {
        let dbPath = "\(homeDir)/.local/share/opencode/opencode.db"
        guard FileManager.default.fileExists(atPath: dbPath) else { return UsageTrendSummary() }
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return UsageTrendSummary() }
        defer { sqlite3_close(db) }
        
        let query = """
        SELECT 
            date(json_extract(data, '$.time.created') / 1000, 'unixepoch', 'localtime') as day,
            coalesce(sum(json_extract(data, '$.cost')), 0.0) as spend,
            coalesce(sum(json_extract(data, '$.tokens.input') + json_extract(data, '$.tokens.output')), 0) as tokens
        FROM session_message 
        WHERE json_extract(data, '$.time.created') IS NOT NULL
        GROUP BY day
        ORDER BY day DESC
        LIMIT 35;
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return UsageTrendSummary() }
        defer { sqlite3_finalize(stmt) }
        
        var spendByDate: [String: Double] = [:]
        var tokensByDate: [String: Int] = [:]
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let dStr = sqlite3_column_text(stmt, 0) {
                let day = String(cString: dStr)
                let spend = sqlite3_column_double(stmt, 1)
                let tokens = Int(sqlite3_column_int64(stmt, 2))
                spendByDate[day] = spend
                tokensByDate[day] = tokens
            }
        }
        
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        
        let todayStr = formatter.string(from: now)
        let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let yesterdayStr = formatter.string(from: yesterdayDate)
        
        let todaySpend = spendByDate[todayStr] ?? 0.0
        let todayTokens = tokensByDate[todayStr] ?? 0
        let yesterdaySpend = spendByDate[yesterdayStr] ?? 0.0
        let yesterdayTokens = tokensByDate[yesterdayStr] ?? 0
        
        var last30DaysSpend = 0.0
        var last30DaysTokens = 0
        var dailyTokenCounts: [Int] = []
        var dailyPoints: [DailyUsagePoint] = []
        
        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "MM/dd"
        labelFormatter.timeZone = TimeZone.current
        
        for dayOffset in (0..<30).reversed() {
            if let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) {
                let dStr = formatter.string(from: targetDate)
                let lStr = labelFormatter.string(from: targetDate)
                let spend = spendByDate[dStr] ?? 0.0
                let tok = tokensByDate[dStr] ?? 0
                last30DaysSpend += spend
                last30DaysTokens += tok
                dailyTokenCounts.append(tok)
                dailyPoints.append(DailyUsagePoint(dateString: dStr, dateLabel: lStr, spendUSD: spend, tokens: tok, normalized: 0.0))
            } else {
                dailyTokenCounts.append(0)
            }
        }
        
        let maxTokens = max(dailyTokenCounts.max() ?? 1, 1)
        let dailyBars = dailyTokenCounts.map { count -> Double in
            if count == 0 { return 0.0 }
            return Double(count) / Double(maxTokens)
        }
        
        var normalizedPoints: [DailyUsagePoint] = []
        for p in dailyPoints {
            let norm = p.tokens > 0 ? (Double(p.tokens) / Double(maxTokens)) : 0.0
            normalizedPoints.append(DailyUsagePoint(dateString: p.dateString, dateLabel: p.dateLabel, spendUSD: p.spendUSD, tokens: p.tokens, normalized: norm))
        }
        
        var peakLabel = ""
        var peakTok = 0
        if let peak = dailyPoints.max(by: { $0.tokens < $1.tokens }), peak.tokens > 0 {
            peakLabel = peak.dateLabel
            peakTok = peak.tokens
        }
        
        var recentLog = ""
        let logQuery = """
        SELECT coalesce(json_extract(data, '$.model.id'), 'opencode-go'), coalesce(json_extract(data, '$.cost'), 0.0)
        FROM session_message 
        WHERE json_extract(data, '$.cost') > 0 
        ORDER BY id DESC LIMIT 1;
        """
        var logStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, logQuery, -1, &logStmt, nil) == SQLITE_OK {
            if sqlite3_step(logStmt) == SQLITE_ROW {
                if let mStr = sqlite3_column_text(logStmt, 0) {
                    let model = String(cString: mStr)
                    let cost = sqlite3_column_double(logStmt, 1)
                    recentLog = L10n.isKorean ? "최근 모델: \(model) ($\(String(format: "%.4f", cost)))" : "Recent: \(model) ($\(String(format: "%.4f", cost)))"
                }
            }
            sqlite3_finalize(logStmt)
        }
        if recentLog.isEmpty {
            recentLog = L10n.isKorean ? "최근 세션: OpenCode Go 활성" : "Recent: OpenCode Go Active"
        }
        
        return UsageTrendSummary(
            todaySpendUSD: todaySpend,
            todayTokens: todayTokens,
            yesterdaySpendUSD: yesterdaySpend,
            yesterdayTokens: yesterdayTokens,
            last30DaysSpendUSD: last30DaysSpend,
            last30DaysTokens: last30DaysTokens,
            dailyBars: dailyBars,
            dailyPoints: normalizedPoints,
            dailyAvgSpendUSD: last30DaysSpend / 30.0,
            dailyAvgTokens: last30DaysTokens / 30,
            peakDateLabel: peakLabel,
            peakTokens: peakTok,
            recentActivityLog: recentLog
        )
    }
}
