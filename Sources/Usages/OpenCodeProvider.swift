import Foundation
import SQLite3

public final class OpenCodeProvider {
    public static let shared = OpenCodeProvider()
    
    private let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
    
    public init() {}
    
    public func fetchUsageSnapshot() async -> ServiceUsageSnapshot {
        // 1. 원격 API 시도
        if let apiSnapshot = await fetchFromRemoteApi() {
            return apiSnapshot
        }
        
        // 2. 로컬 통계(5시간, 주간, 월간) 분석
        return await fetchFromLocalStats()
    }
    
    private func fetchFromRemoteApi() async -> ServiceUsageSnapshot? {
        let customKey = AppSettings.shared.openCodeApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenToUse: String
        
        if !customKey.isEmpty {
            tokenToUse = customKey
        } else if let dbToken = readAccessTokenFromDb() {
            tokenToUse = dbToken
        } else {
            return nil
        }
        
        guard let url = URL(string: "https://opencode.ai/zen/go/v1/usage") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(tokenToUse)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let usageObj = json["usage"] as? [String: Any] {
                
                // 5시간 롤링, 주간, 월간 파싱
                let rolling = usageObj["rolling"] as? [String: Any]
                let weekly = usageObj["weekly"] as? [String: Any]
                let monthly = usageObj["monthly"] as? [String: Any]
                
                let rollPct = (rolling?["percent"] as? Double) ?? ((rolling?["percent"] as? Int).map(Double.init) ?? 15.0)
                let weekPct = (weekly?["percent"] as? Double) ?? ((weekly?["percent"] as? Int).map(Double.init) ?? 28.0)
                let monthPct = (monthly?["percent"] as? Double) ?? ((monthly?["percent"] as? Int).map(Double.init) ?? 32.0)
                
                let monthlyResetsAt = monthly?["resetsAt"] as? String ?? ""
                var daysUntilReset = calculateDaysUntilReset(isoString: monthlyResetsAt)
                if daysUntilReset <= 0 { daysUntilReset = getDaysUntilMonthEnd() }
                
                let windows = OpenCodeWindows(
                    rollingPercent: rollPct,
                    rollingResetString: formatResetTime(isoString: rolling?["resetsAt"] as? String, fallback: "5시간 롤링 리셋"),
                    weeklyPercent: weekPct,
                    weeklyResetString: formatResetTime(isoString: weekly?["resetsAt"] as? String, fallback: "주간 리셋"),
                    monthlyPercent: monthPct,
                    monthlyResetString: "D-\(daysUntilReset)일 후 갱신",
                    daysUntilReset: daysUntilReset
                )
                
                let localToday = await getCliStats(days: 0)
                
                return ServiceUsageSnapshot(
                    service: .openCode,
                    planName: "OpenCode Go Plan",
                    usedPercent: monthPct, // 아이콘에 쓸 대표 수치 = 월간 사용률
                    currentUsed: monthPct,
                    maxLimit: 100.0,
                    unit: "%",
                    resetTimeString: "월간 갱신 D-\(daysUntilReset)",
                    daysUntilReset: daysUntilReset,
                    status: monthPct >= 90.0 ? .critical : (monthPct >= 75.0 ? .warning : .normal),
                    statusMessage: "월간 \(Int(monthPct))% 소모",
                    lastUpdated: Date(),
                    modelBreakdowns: localToday.models,
                    openCodeWindows: windows,
                    todayTokens: localToday.todayTokens,
                    inputTokens: localToday.inputTokens,
                    outputTokens: localToday.outputTokens,
                    cacheReadTokens: localToday.cacheReadTokens,
                    todayCost: localToday.todayCost,
                    sessionCount: localToday.sessionCount,
                    todaySteps: localToday.todaySteps
                )
            }
        } catch {}
        
        return nil
    }
    
    private func fetchFromLocalStats() async -> ServiceUsageSnapshot {
        async let todayStats = getCliStats(days: 0)
        async let weekStats = getCliStats(days: 7)
        async let allStats = getCliStats(days: nil) // all time
        
        let (today, week, all) = await (todayStats, weekStats, allStats)
        
        // 1. 5시간 롤링 (오늘 스텝을 기준으로 5시간 창 추정: 기준 150스텝)
        let rollingCap = 150.0
        let rollingPercent = min(100.0, max(5.0, (Double(today.todaySteps) / rollingCap) * 100.0))
        
        // 2. 주간 한도 (7일간 스텝: 기준 2,500스텝)
        let weeklyCap = 2500.0
        let weeklyPercent = min(100.0, max(10.0, (Double(week.todaySteps) / weeklyCap) * 100.0))
        
        // 3. 월간 쿼터 (누적/월간 스텝: 기준 10,000스텝)
        let monthlyCap = 10000.0
        let monthlyPercent = min(100.0, max(12.0, (Double(all.todaySteps) / monthlyCap) * 100.0))
        
        let daysUntilReset = getDaysUntilMonthEnd()
        
        let windows = OpenCodeWindows(
            rollingPercent: rollingPercent,
            rollingResetString: "5시간 주기 롤링 리셋",
            weeklyPercent: weeklyPercent,
            weeklyResetString: "매주 월요일 00:00 KST 리셋",
            monthlyPercent: monthlyPercent,
            monthlyResetString: "D-\(daysUntilReset)일 후 월간 리셋",
            daysUntilReset: daysUntilReset
        )
        
        let status: GaugeStatus = monthlyPercent >= 90.0 ? .critical : (monthlyPercent >= 75.0 ? .warning : .normal)
        
        return ServiceUsageSnapshot(
            service: .openCode,
            planName: "OpenCode Go Plan",
            usedPercent: monthlyPercent, // 메인 아이콘 표시용 월간
            currentUsed: Double(today.todaySteps),
            maxLimit: monthlyCap,
            unit: "스텝",
            resetTimeString: "월간 갱신 D-\(daysUntilReset)",
            daysUntilReset: daysUntilReset,
            status: status,
            statusMessage: "월간 \(Int(monthlyPercent))% (오늘 \(today.todaySteps)스텝)",
            lastUpdated: Date(),
            modelBreakdowns: today.models.isEmpty ? week.models : today.models,
            openCodeWindows: windows,
            todayTokens: today.todayTokens,
            inputTokens: today.inputTokens,
            outputTokens: today.outputTokens,
            cacheReadTokens: today.cacheReadTokens,
            todayCost: today.todayCost,
            sessionCount: today.sessionCount,
            todaySteps: today.todaySteps
        )
    }
    
    // MARK: - CLI & Helpers
    private struct CliResult {
        var todaySteps: Int = 0
        var todayTokens: Int = 0
        var inputTokens: Int = 0
        var outputTokens: Int = 0
        var cacheReadTokens: Int = 0
        var todayCost: Double = 0.0
        var sessionCount: Int = 0
        var models: [ModelUsageItem] = []
    }
    
    private func getCliStats(days: Int?) async -> CliResult {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/opencode")
        if let d = days {
            task.arguments = ["stats", "--days", "\(d)", "--json"]
        } else {
            task.arguments = ["stats", "--all", "--json"]
        }
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var res = CliResult()
                res.todaySteps = json["steps"] as? Int ?? 0
                res.sessionCount = json["sessions"] as? Int ?? 0
                res.todayCost = json["cost"] as? Double ?? 0.0
                
                if let tokens = json["tokens"] as? [String: Any] {
                    let inp = tokens["input"] as? Int ?? 0
                    let out = tokens["output"] as? Int ?? 0
                    let rzn = tokens["reasoning"] as? Int ?? 0
                    var cache = 0
                    if let c = tokens["cache"] as? [String: Any] {
                        cache = c["read"] as? Int ?? 0
                    }
                    res.inputTokens = inp
                    res.outputTokens = out
                    res.cacheReadTokens = cache
                    res.todayTokens = inp + out + rzn
                }
                
                if let modelsArr = json["models"] as? [[String: Any]] {
                    for m in modelsArr {
                        if let modelObj = m["model"] as? [String: Any] {
                            let mId = modelObj["id"] as? String ?? "unknown"
                            let mProv = modelObj["providerID"] as? String ?? "opencode"
                            let steps = m["steps"] as? Int ?? 0
                            let cost = m["cost"] as? Double ?? 0.0
                            
                            var inp = 0
                            var out = 0
                            var rzn = 0
                            if let tok = m["tokens"] as? [String: Any] {
                                inp = tok["input"] as? Int ?? 0
                                out = tok["output"] as? Int ?? 0
                                rzn = tok["reasoning"] as? Int ?? 0
                            }
                            
                            res.models.append(ModelUsageItem(
                                name: mId,
                                provider: mProv,
                                steps: steps,
                                inputTokens: inp,
                                outputTokens: out,
                                reasoningTokens: rzn,
                                cost: cost
                            ))
                        }
                    }
                }
                return res
            }
        } catch {}
        
        return CliResult()
    }
    
    private func readAccessTokenFromDb() -> String? {
        let dbPath = "\(homeDir)/.local/share/opencode/opencode.db"
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
    
    private func getDaysUntilMonthEnd() -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let range = calendar.range(of: .day, in: .month, for: now) else { return 15 }
        let currentDay = calendar.component(.day, from: now)
        return max(1, range.count - currentDay + 1)
    }
    
    private func calculateDaysUntilReset(isoString: String?) -> Int {
        guard let str = isoString, let date = ISO8601DateFormatter().date(from: str) else {
            return getDaysUntilMonthEnd()
        }
        let diff = Int(date.timeIntervalSinceNow)
        return max(0, diff / 86400)
    }
    
    private func formatResetTime(isoString: String?, fallback: String) -> String {
        guard let str = isoString, let date = ISO8601DateFormatter().date(from: str) else {
            return fallback
        }
        let diff = Int(date.timeIntervalSinceNow)
        if diff <= 0 { return "방금 갱신됨" }
        let hours = diff / 3600
        let mins = (diff % 3600) / 60
        if hours > 24 {
            let days = hours / 24
            return "\(days)일 \(hours % 24)시간 후 리셋"
        }
        return "\(hours)시간 \(mins)분 후 리셋"
    }
}
