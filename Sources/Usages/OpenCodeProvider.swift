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
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let usageObj = json["usage"] as? [String: Any],
                  let rolling = usageObj["rolling"] as? [String: Any],
                  let weekly = usageObj["weekly"] as? [String: Any],
                  let monthly = usageObj["monthly"] as? [String: Any],
                  let rollUsed = number(rolling["percent"]),
                  let weekUsed = number(weekly["percent"]),
                  let monthUsed = number(monthly["percent"]) else {
                // Never invent percentages. A partial/malformed payload must fall
                // through to the cached snapshot instead of showing fake data.
                return nil
            }
            
            let rollRem = max(0.0, 100.0 - rollUsed)
            let weekRem = max(0.0, 100.0 - weekUsed)
            let monthRem = max(0.0, 100.0 - monthUsed)
            
            let rollReset = formatCountdown(isoString: rolling["resetsAt"] as? String)
            let weekReset = formatCountdown(isoString: weekly["resetsAt"] as? String)
            let monthReset = formatCountdown(isoString: monthly["resetsAt"] as? String)
            let daysRem = calculateDaysRemaining(isoString: monthly["resetsAt"] as? String)
            
            let fiveHourStr = resetLabel(rollReset)
            let weeklyStr = resetLabel(weekReset)
            let monthlyStr = resetLabel(monthReset)
            let billingStr = monthlyStr
            
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
        } catch {}
        
        return nil
    }
    
    private func readAccessTokenFromDb() -> String? {
        let dbPath = "\(homeDir)/.local/share/opencode/opencode.db"
        if FileManager.default.fileExists(atPath: dbPath),
           let token = readTokenFromDatabase(at: dbPath) {
            return token
        }
        // OpenCode v1 kept credentials in auth.json; keep the fallback so older
        // installations are still detected.
        return readTokenFromAuthFile()
    }

    /// Reads the credential row for OpenCode Go.
    ///
    /// OpenCode v2 stores an API key (`{"type":"key","key":"oc_sk_..."}`) under
    /// `integration_id = 'opencode-go'`, whereas older builds stored an OAuth
    /// session (`{"access":"..."}`) under `integration_id = 'opencode'`. Both
    /// shapes are accepted, and active rows win over stale ones.
    private func readTokenFromDatabase(at dbPath: String) -> String? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 1_000)
        
        var stmt: OpaquePointer?
        let query = """
        SELECT value FROM credential
        WHERE integration_id IN ('opencode-go', 'opencode')
           OR connector_id IN ('opencode-go', 'opencode')
           OR label IN ('OpenCode Go', 'OpenCode', 'Default')
        ORDER BY active DESC, time_updated DESC
        LIMIT 20;
        """
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cStr = sqlite3_column_text(stmt, 0) else { continue }
            if let token = Self.token(fromCredentialJSON: String(cString: cStr)) {
                return token
            }
        }
        return nil
    }
    
    private func readTokenFromAuthFile() -> String? {
        let candidates = [
            "\(homeDir)/.local/share/opencode/auth.json",
            "\(homeDir)/.config/opencode/auth.json"
        ]
        for path in candidates {
            guard let data = FileManager.default.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let entry = (json["opencode-go"] as? [String: Any]) ?? (json["opencode"] as? [String: Any])
            if let entry, let token = Self.token(fromCredentialDictionary: entry) {
                return token
            }
        }
        return nil
    }
    
    static func token(fromCredentialJSON jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return token(fromCredentialDictionary: dict)
    }
    
    static func token(fromCredentialDictionary dict: [String: Any]) -> String? {
        // `key` is the v2 API key; `access` is the legacy OAuth access token.
        let keys = ["access", "access_token", "accessToken", "key", "apiKey", "api_key", "token"]
        for key in keys {
            if let value = dict[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        if let nested = dict["tokens"] as? [String: Any],
           let token = token(fromCredentialDictionary: nested) {
            return token
        }
        return nil
    }
    
    private func number(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }
    
    private func formatCountdown(isoString: String?) -> String {
        guard let date = ISO8601Parser.date(from: isoString) else {
            return "-"
        }
        let diff = max(0, Int(date.timeIntervalSinceNow))
        let days = diff / 86400
        let hours = (diff % 86400) / 3600
        let mins = (diff % 3600) / 60
        
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
    
    private func resetLabel(_ countdown: String) -> String {
        guard countdown != "-" else { return "-" }
        return L10n.isKorean ? "\(countdown) 후 리셋" : "Resets in \(countdown)"
    }
    
    private func calculateDaysRemaining(isoString: String?) -> Int {
        guard let date = ISO8601Parser.date(from: isoString) else {
            // Unknown reset date: return a large value so the menu-bar "reset
            // imminent" dot is not shown for missing data.
            return 999
        }
        return max(0, Int(ceil(date.timeIntervalSinceNow / 86400.0)))
    }
    
    private func fetchLocalUsageTrend() -> UsageTrendSummary {
        let dbPath = "\(homeDir)/.local/share/opencode/opencode.db"
        guard FileManager.default.fileExists(atPath: dbPath) else { return UsageTrendSummary() }
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return UsageTrendSummary() }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 1_000)
        
        // OpenCode's own `stats` command counts input + output + reasoning +
        // cache read/write. Summing only input+output under-reported usage by
        // roughly an order of magnitude (cache reads dominate real traffic).
        let query = """
        SELECT 
            date(time_created / 1000, 'unixepoch', 'localtime') as day,
            coalesce(sum(json_extract(data, '$.cost')), 0.0) as spend,
            coalesce(sum(
                coalesce(json_extract(data, '$.tokens.input'), 0) +
                coalesce(json_extract(data, '$.tokens.output'), 0) +
                coalesce(json_extract(data, '$.tokens.reasoning'), 0) +
                coalesce(json_extract(data, '$.tokens.cache.read'), 0) +
                coalesce(json_extract(data, '$.tokens.cache.write'), 0)
            ), 0) as tokens
        FROM session_message 
        WHERE type = 'assistant' AND time_created >= ?
        GROUP BY day
        ORDER BY day DESC
        LIMIT 35;
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return UsageTrendSummary() }
        defer { sqlite3_finalize(stmt) }
        
        // Bound the scan (the DB is large and grows constantly).
        let cutoff = Int64(Date().addingTimeInterval(-35 * 86400).timeIntervalSince1970 * 1000)
        sqlite3_bind_int64(stmt, 1, cutoff)
        
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
        WHERE type = 'assistant' AND json_extract(data, '$.cost') > 0 
        ORDER BY time_created DESC LIMIT 1;
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
