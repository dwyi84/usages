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
            let monthSpend = keyInfo?.usageMonthly ?? trend.last30DaysSpendUSD
            
            let snapshot = TokenCostSnapshot(
                providerId: "openrouter",
                providerName: "OpenRouter",
                balanceUSD: balance,
                todaySpendUSD: trend.todaySpendUSD,
                monthSpendUSD: monthSpend,
                totalTokens: keyInfo?.lifetimeTokens ?? trend.last30DaysTokens,
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
        let usageDaily: Double
        let usageWeekly: Double
        let usageMonthly: Double
        let usageTotal: Double
        let promptTokens: Int
        let completionTokens: Int
        let requestsCount: Int
        
        var lifetimeTokens: Int { promptTokens + completionTokens }
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
            let usageTotal = number(dataDict["usage"]) ?? 0.0
            // These are real fields on /api/v1/key. Never invent a daily value
            // (the previous `usageTotal * 0.15` fallback fabricated usage).
            let usageDaily = number(dataDict["usage_daily"]) ?? 0.0
            let usageWeekly = number(dataDict["usage_weekly"]) ?? 0.0
            let usageMonthly = number(dataDict["usage_monthly"]) ?? 0.0
            let prompt = Int(number(dataDict["prompt_tokens"]) ?? 0)
            let comp = Int(number(dataDict["completion_tokens"]) ?? 0)
            
            return KeyInfoResult(
                usageDaily: usageDaily,
                usageWeekly: usageWeekly,
                usageMonthly: usageMonthly,
                usageTotal: usageTotal,
                promptTokens: prompt,
                completionTokens: comp,
                requestsCount: 0
            )
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
        // OpenRouter's activity payload is keyed by UTC dates and is only
        // available to management keys. Use UTC consistently for both the
        // bucket keys and the chart labels; the previous mix (UTC data with
        // local labels) could show yesterday's data under today's label.
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = utcCalendar.timeZone
        
        let todayStr = formatter.string(from: now)
        let yesterdayDate = utcCalendar.date(byAdding: .day, value: -1, to: now) ?? now
        let yesterdayStr = formatter.string(from: yesterdayDate)
        
        var spendByDate: [String: Double] = [:]
        var tokensByDate: [String: Int] = [:]
        
        for row in activityRows {
            spendByDate[row.date, default: 0.0] += row.usage
            tokensByDate[row.date, default: 0] += row.tokens
        }
        
        let hasActivity = !activityRows.isEmpty
        let todaySpend = spendByDate[todayStr] ?? keyInfo?.usageDaily ?? 0.0
        let todayTokens = tokensByDate[todayStr] ?? 0
        let yesterdaySpend = spendByDate[yesterdayStr] ?? 0.0
        let yesterdayTokens = tokensByDate[yesterdayStr] ?? 0
        
        var last30DaysSpend = 0.0
        var last30DaysTokens = 0
        var dailyTokenCounts: [Int] = []
        var dailyPoints: [DailyUsagePoint] = []
        
        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "MM/dd"
        labelFormatter.timeZone = utcCalendar.timeZone
        
        for dayOffset in (0..<30).reversed() {
            if let targetDate = utcCalendar.date(byAdding: .day, value: -dayOffset, to: now) {
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
        
        // Without a management key the activity endpoint is unavailable. Use
        // the daily/monthly counters from /api/v1/key instead, and make sure the
        // "today" bar agrees with the "today" summary. Never substitute the
        // lifetime counter for a 30-day total.
        if !hasActivity {
            var sum = keyInfo?.usageMonthly ?? 0.0
            if sum <= 0 { sum = keyInfo?.usageWeekly ?? 0.0 }
            if sum <= 0 { sum = todaySpend }
            last30DaysSpend = sum
            last30DaysTokens = todayTokens
            if !dailyPoints.isEmpty {
                let last = dailyPoints.count - 1
                dailyPoints[last] = DailyUsagePoint(
                    dateString: dailyPoints[last].dateString,
                    dateLabel: dailyPoints[last].dateLabel,
                    spendUSD: todaySpend,
                    tokens: todayTokens,
                    normalized: 0.0
                )
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
        
        let recentLog = (keyInfo != nil && (keyInfo?.usageTotal ?? 0) > 0)
            ? (L10n.isKorean ? "프롬프트: \(keyInfo?.promptTokens ?? 0) · 완성: \(keyInfo?.completionTokens ?? 0)" : "Prompt: \(keyInfo?.promptTokens ?? 0) · Comp: \(keyInfo?.completionTokens ?? 0)")
            : (L10n.isKorean ? "API 키 정상 연동됨" : "API Key Connected")
        
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
