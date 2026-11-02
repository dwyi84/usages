import Foundation

public final class OpenRouterProvider: @unchecked Sendable {
    public static let shared = OpenRouterProvider()
    
    private var cachedSnapshot = TokenCostSnapshot(providerId: "openrouter", providerName: "OpenRouter", isConnected: false)
    private var isFetching = false
    
    public init() {}
    
    public var isAvailable: Bool {
        let key = AppSettings.shared.openRouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !key.isEmpty
    }
    
    public func fetchSnapshot() async -> TokenCostSnapshot {
        let key = AppSettings.shared.openRouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            return TokenCostSnapshot(providerId: "openrouter", providerName: "OpenRouter", isConnected: false)
        }
        
        guard !isFetching else { return cachedLimitsOrDisconnected() }
        isFetching = true
        defer { isFetching = false }
        
        do {
            async let creditsData = fetchCredits(key: key)
            async let keyData = fetchKeyInfo(key: key)
            async let activityData = fetchActivity(key: key)
            
            let (credits, keyInfo, activityRows) = try await (creditsData, keyData, activityData)
            
            let balance = credits?.balance ?? 0.0
            let trend = buildTrendSummary(activityRows: activityRows, keyInfo: keyInfo)
            
            let snapshot = TokenCostSnapshot(
                providerId: "openrouter",
                providerName: "OpenRouter",
                balanceUSD: balance,
                todaySpendUSD: trend.todaySpendUSD,
                monthSpendUSD: trend.last30DaysSpendUSD,
                totalTokens: trend.last30DaysTokens,
                promptTokens: keyInfo?.promptTokens ?? 0,
                completionTokens: keyInfo?.completionTokens ?? 0,
                cachedTokens: 0,
                requestsCount: keyInfo?.requestsCount ?? 0,
                status: balance <= 1.0 ? .warning : .normal,
                lastUpdated: Date(),
                isConnected: true,
                trendSummary: trend
            )
            
            cachedSnapshot = snapshot
            return snapshot
        } catch {
            var stale = cachedSnapshot
            stale.status = .warning
            return stale
        }
    }
    
    private func cachedLimitsOrDisconnected() -> TokenCostSnapshot {
        return cachedSnapshot
    }
    
    // MARK: - OpenRouter APIs
    private struct CreditsResult {
        let balance: Double
    }
    
    private struct KeyInfoResult {
        let usageToday: Double
        let usageTotal: Double
        let promptTokens: Int
        let completionTokens: Int
        let requestsCount: Int
    }
    
    private func fetchCredits(key: String) async throws -> CreditsResult? {
        guard let url = URL(string: "https://openrouter.ai/api/v1/credits") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 6.0
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataDict = json["data"] as? [String: Any] {
            let total = (dataDict["total_credits"] as? Double) ?? 0.0
            let usage = (dataDict["total_usage"] as? Double) ?? 0.0
            let balance = max(0.0, total - usage)
            return CreditsResult(balance: balance)
        }
        return nil
    }
    
    private func fetchKeyInfo(key: String) async throws -> KeyInfoResult? {
        guard let url = URL(string: "https://openrouter.ai/api/v1/key") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 6.0
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataDict = json["data"] as? [String: Any] {
            let usageTotal = (dataDict["usage"] as? Double) ?? 0.0
            let usageDaily = (dataDict["usage_daily"] as? Double) ?? (usageTotal * 0.15) // 추정 or 제공값
            let prompt = (dataDict["prompt_tokens"] as? Int) ?? 0
            let comp = (dataDict["completion_tokens"] as? Int) ?? 0
            
            return KeyInfoResult(
                usageToday: usageDaily,
                usageTotal: usageTotal,
                promptTokens: prompt,
                completionTokens: comp,
                requestsCount: 0
            )
        }
        return nil
    }
    
    private struct ActivityRow {
        let date: String
        let usage: Double
        let tokens: Int
    }
    
    private func fetchActivity(key: String) async -> [ActivityRow] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/activity") else { return [] }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 6.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return [] }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = json["data"] as? [[String: Any]] else { return [] }
            
            var rows: [ActivityRow] = []
            for item in list {
                guard let date = item["date"] as? String else { continue }
                let usage = (item["usage"] as? Double) ?? Double((item["usage"] as? Int) ?? 0)
                let prompt = (item["prompt_tokens"] as? Int) ?? Int((item["prompt_tokens"] as? Double) ?? 0)
                let completion = (item["completion_tokens"] as? Int) ?? Int((item["completion_tokens"] as? Double) ?? 0)
                rows.append(ActivityRow(date: date, usage: usage, tokens: prompt + completion))
            }
            return rows
        } catch {
            return []
        }
    }
    
    private func buildTrendSummary(activityRows: [ActivityRow], keyInfo: KeyInfoResult?) -> UsageTrendSummary {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        
        let todayStr = formatter.string(from: now)
        let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let yesterdayStr = formatter.string(from: yesterdayDate)
        
        var spendByDate: [String: Double] = [:]
        var tokensByDate: [String: Int] = [:]
        
        for row in activityRows {
            spendByDate[row.date, default: 0.0] += row.usage
            tokensByDate[row.date, default: 0] += row.tokens
        }
        
        var todaySpend = spendByDate[todayStr] ?? 0.0
        var todayTokens = tokensByDate[todayStr] ?? 0
        if todaySpend == 0, let key = keyInfo, key.usageToday > 0 {
            todaySpend = key.usageToday
            todayTokens = key.promptTokens + key.completionTokens
        }
        
        let yesterdaySpend = spendByDate[yesterdayStr] ?? 0.0
        let yesterdayTokens = tokensByDate[yesterdayStr] ?? 0
        
        var last30DaysSpend = 0.0
        var last30DaysTokens = 0
        var dailyTokenCounts: [Int] = []
        
        for dayOffset in (0..<30).reversed() {
            if let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) {
                let dStr = formatter.string(from: targetDate)
                let spend = spendByDate[dStr] ?? 0.0
                let tok = tokensByDate[dStr] ?? 0
                last30DaysSpend += spend
                last30DaysTokens += tok
                dailyTokenCounts.append(tok)
            } else {
                dailyTokenCounts.append(0)
            }
        }
        
        if last30DaysSpend == 0, let key = keyInfo, key.usageTotal > 0 {
            last30DaysSpend = key.usageTotal
            last30DaysTokens = max(todayTokens, key.promptTokens + key.completionTokens)
        }
        
        let maxTokens = max(dailyTokenCounts.max() ?? 1, 1)
        let dailyBars = dailyTokenCounts.map { count -> Double in
            if count == 0 { return 0.0 }
            return Double(count) / Double(maxTokens)
        }
        
        return UsageTrendSummary(
            todaySpendUSD: todaySpend,
            todayTokens: todayTokens,
            yesterdaySpendUSD: yesterdaySpend,
            yesterdayTokens: yesterdayTokens,
            last30DaysSpendUSD: last30DaysSpend,
            last30DaysTokens: last30DaysTokens,
            dailyBars: dailyBars
        )
    }
}
