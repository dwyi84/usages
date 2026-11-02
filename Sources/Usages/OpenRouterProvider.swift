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
            
            let (credits, keyInfo) = try await (creditsData, keyData)
            
            let balance = credits?.balance ?? 0.0
            let todaySpend = keyInfo?.usageToday ?? 0.0
            let monthSpend = keyInfo?.usageTotal ?? 0.0
            let prompt = keyInfo?.promptTokens ?? 0
            let completion = keyInfo?.completionTokens ?? 0
            let totalTok = prompt + completion
            
            let snapshot = TokenCostSnapshot(
                providerId: "openrouter",
                providerName: "OpenRouter",
                balanceUSD: balance,
                todaySpendUSD: todaySpend,
                monthSpendUSD: monthSpend,
                totalTokens: totalTok,
                promptTokens: prompt,
                completionTokens: completion,
                cachedTokens: 0,
                requestsCount: keyInfo?.requestsCount ?? 0,
                status: balance <= 1.0 ? .warning : .normal,
                lastUpdated: Date(),
                isConnected: true
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
}
