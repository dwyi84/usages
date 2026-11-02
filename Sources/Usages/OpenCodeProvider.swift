import Foundation
import SQLite3

public final class OpenCodeProvider {
    public static let shared = OpenCodeProvider()
    
    private let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
    
    public init() {}
    
    /// OpenCode Go 사용량 데이터 가져오기
    public func fetchUsageSnapshot() async -> ServiceUsageSnapshot {
        // 1. 먼저 원격 API 조회를 시도
        if let apiSnapshot = await fetchFromRemoteApi() {
            return apiSnapshot
        }
        
        // 2. 로컬 CLI stats 또는 로컬 SQLite DB 조회
        if let localSnapshot = await fetchFromLocalCli() {
            return localSnapshot
        }
        
        // 3. Fallback
        return ServiceUsageSnapshot(
            service: .openCode,
            planName: "OpenCode Go",
            usedPercent: 0.0,
            currentUsed: 0.0,
            maxLimit: 100.0,
            unit: "%",
            resetTimeString: "정보를 불러오는 중...",
            status: .unknown,
            statusMessage: "데이터 대기 중"
        )
    }
    
    // MARK: - Remote API Fetch
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
        request.timeoutInterval = 6.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }
            
            // JSON 응답 파싱
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let usageObj = json["usage"] as? [String: Any] {
                
                // rolling 또는 weekly 또는 monthly
                let rolling = usageObj["rolling"] as? [String: Any]
                let percent = (rolling?["percent"] as? Double) ?? ((rolling?["percent"] as? Int).map(Double.init) ?? 0.0)
                let resetsAt = rolling?["resetsAt"] as? String ?? "5시간 롤링"
                
                var resetStr = "5시간 롤링"
                if let isoDate = ISO8601DateFormatter().date(from: resetsAt) {
                    let diff = Int(isoDate.timeIntervalSinceNow)
                    if diff > 0 {
                        let hours = diff / 3600
                        let mins = (diff % 3600) / 60
                        resetStr = "\(hours)시간 \(mins)분 후 리셋"
                    } else {
                        resetStr = "방금 갱신됨"
                    }
                }
                
                let status: GaugeStatus
                if percent >= 90.0 {
                    status = .critical
                } else if percent >= 70.0 {
                    status = .warning
                } else {
                    status = .normal
                }
                
                // 로컬 통계도 함께 결합
                let localStats = await getTodayLocalStats()
                
                return ServiceUsageSnapshot(
                    service: .openCode,
                    planName: "OpenCode Go Plan",
                    usedPercent: percent,
                    currentUsed: percent,
                    maxLimit: 100.0,
                    unit: "%",
                    resetTimeString: resetStr,
                    status: status,
                    statusMessage: "\(Int(percent))% 사용됨",
                    lastUpdated: Date(),
                    modelBreakdowns: localStats.models,
                    todayTokens: localStats.todayTokens,
                    inputTokens: localStats.inputTokens,
                    outputTokens: localStats.outputTokens,
                    cacheReadTokens: localStats.cacheReadTokens,
                    todayCost: localStats.todayCost,
                    sessionCount: localStats.sessionCount,
                    todaySteps: localStats.todaySteps
                )
            }
        } catch {
            // 실패 시 로컬 stats로 원활히 fallback
        }
        
        return nil
    }
    
    // MARK: - Local CLI & DB Fetch
    private func fetchFromLocalCli() async -> ServiceUsageSnapshot? {
        let stats = await getTodayLocalStats()
        
        // OpenCode Go는 무제한/대용량 쿼터이므로, 오늘의 작업량을 기준으로 직관적인 사용량 시각화
        // 일일 목표량(Soft cap 기준 예: 500 Steps or 5,000,000 Tokens) 대비 오늘 소모율 계산
        let baseStepCap = 500.0
        let calculatedPercent = min(100.0, max(2.0, (Double(stats.todaySteps) / baseStepCap) * 100.0))
        
        let status: GaugeStatus
        if calculatedPercent >= 90.0 {
            status = .warning
        } else {
            status = .normal
        }
        
        return ServiceUsageSnapshot(
            service: .openCode,
            planName: "OpenCode Go Plan",
            usedPercent: calculatedPercent,
            currentUsed: Double(stats.todaySteps),
            maxLimit: baseStepCap,
            unit: "스텝",
            resetTimeString: "자정 (00:00 KST) 리셋",
            status: status,
            statusMessage: "오늘 \(stats.todaySteps)스텝 (\(formatTokens(stats.todayTokens)))",
            lastUpdated: Date(),
            modelBreakdowns: stats.models,
            todayTokens: stats.todayTokens,
            inputTokens: stats.inputTokens,
            outputTokens: stats.outputTokens,
            cacheReadTokens: stats.cacheReadTokens,
            todayCost: stats.todayCost,
            sessionCount: stats.sessionCount,
            todaySteps: stats.todaySteps
        )
    }
    
    // MARK: - Helper Struct
    private struct LocalStatsResult {
        var todaySteps: Int = 0
        var todayTokens: Int = 0
        var inputTokens: Int = 0
        var outputTokens: Int = 0
        var cacheReadTokens: Int = 0
        var todayCost: Double = 0.0
        var sessionCount: Int = 0
        var models: [ModelUsageItem] = []
    }
    
    private func getTodayLocalStats() async -> LocalStatsResult {
        // opencode stats --days 0 --json 실행
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/opencode")
        task.arguments = ["stats", "--days", "0", "--json"]
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var res = LocalStatsResult()
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
        } catch {
            // CLI 실패 시 DB 직접 조회 시도
        }
        
        return LocalStatsResult()
    }
    
    /// SQLite DB에서 Access Token 읽기
    private func readAccessTokenFromDb() -> String? {
        let dbPath = "\(homeDir)/.local/share/opencode/opencode.db"
        var db: OpaquePointer?
        
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }
        
        var stmt: OpaquePointer?
        let query = "SELECT value FROM credential WHERE integration_id = 'opencode' OR label = 'Default' LIMIT 1;"
        
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_step(stmt) == SQLITE_ROW {
            if let cStr = sqlite3_column_text(stmt, 0) {
                let jsonStr = String(cString: cStr)
                if let jsonData = jsonStr.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    return dict["access"] as? String
                }
            }
        }
        return nil
    }
    
    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM 토큰", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK 토큰", Double(count) / 1_000.0)
        } else {
            return "\(count) 토큰"
        }
    }
}
