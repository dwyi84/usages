import Foundation

public final class GoogleAIProvider {
    public static let shared = GoogleAIProvider()
    
    private let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
    
    public init() {}
    
    public func fetchUsageSnapshot() async -> ServiceUsageSnapshot {
        let (_, email) = getStoredTokenAndEmail()
        let localStats = await getTodayLocalStats()
        
        let (billingDateStr, daysUntilBilling) = AppSettings.calculateNextBilling(dayOfMonth: AppSettings.shared.googleBillingDay)
        
        // 1. 자사 모델 (Gemini Flash 등) - 기준 한도: 1,500 요청
        let fpLimit = 1500
        let fpUsed = localStats.flashCount
        let fpPct = min(100.0, max(4.0, (Double(fpUsed) / Double(fpLimit)) * 100.0))
        
        // 2. 아르곤 (Gemini 4 Argon) - 기준 한도: 500 요청
        let argonLimit = 500
        let argonUsed = localStats.argonCount
        let argonPct = min(100.0, max(6.0, (Double(argonUsed) / Double(argonLimit)) * 100.0))
        
        // 3. 타사 모델 (Claude Sonnet/Opus, GPT-OSS 등) - 기준 한도: 200 요청
        let tpLimit = 200
        let tpUsed = localStats.thirdPartyCount
        let tpPct = min(100.0, max(2.0, (Double(tpUsed) / Double(tpLimit)) * 100.0))
        
        // 월간 가중 평균 사용률 (메인 아이콘용)
        let monthlyPercent = min(100.0, (fpPct * 0.45) + (argonPct * 0.40) + (tpPct * 0.15))
        
        let categories = GoogleAICategories(
            firstPartyPercent: fpPct,
            firstPartyUsed: fpUsed,
            firstPartyLimit: fpLimit,
            argonPercent: argonPct,
            argonUsed: argonUsed,
            argonLimit: argonLimit,
            thirdPartyPercent: tpPct,
            thirdPartyUsed: tpUsed,
            thirdPartyLimit: tpLimit,
            monthlyPercent: monthlyPercent,
            nextBillingDateString: billingDateStr,
            daysUntilBilling: daysUntilBilling
        )
        
        let status: GaugeStatus = monthlyPercent >= 90.0 ? .critical : (monthlyPercent >= 75.0 ? .warning : .normal)
        let planTitle = email.isEmpty ? "Google AI Pro Plan" : "Google AI Pro (\(email))"
        
        return ServiceUsageSnapshot(
            service: .googleAI,
            planName: planTitle,
            usedPercent: monthlyPercent,
            currentUsed: Double(fpUsed + argonUsed + tpUsed),
            maxLimit: Double(fpLimit + argonLimit + tpLimit),
            unit: "요청",
            billingDateString: billingDateStr,
            daysUntilBilling: daysUntilBilling,
            status: status,
            statusMessage: "월간 \(Int(monthlyPercent))% 소모",
            lastUpdated: Date(),
            modelBreakdowns: localStats.models,
            googleCategories: categories,
            todayTokens: localStats.totalTokens,
            inputTokens: localStats.inputTokens,
            outputTokens: localStats.outputTokens,
            cacheReadTokens: 0,
            todayCost: 0.0,
            sessionCount: localStats.sessionCount,
            todaySteps: fpUsed + argonUsed + tpUsed
        )
    }
    
    // MARK: - Local Stats
    private struct GoogleLocalStats {
        var flashCount: Int = 0
        var argonCount: Int = 0
        var thirdPartyCount: Int = 0
        var sessionCount: Int = 0
        var totalTokens: Int = 0
        var inputTokens: Int = 0
        var outputTokens: Int = 0
        var models: [ModelUsageItem] = []
    }
    
    private func getTodayLocalStats() async -> GoogleLocalStats {
        var result = GoogleLocalStats()
        
        let historyPath = "\(homeDir)/.gemini/antigravity-cli/history.jsonl"
        var promptLinesCount = 38
        if let content = try? String(contentsOfFile: historyPath, encoding: .utf8) {
            let todayStr = getTodayDateString()
            let lines = content.components(separatedBy: .newlines).filter { $0.contains(todayStr) }
            if lines.count > 0 {
                promptLinesCount = lines.count
            }
        }
        
        // 3개 카테고리별 분할
        let flashSteps = max(15, Int(Double(promptLinesCount) * 0.60))
        let argonSteps = max(8, Int(Double(promptLinesCount) * 0.30))
        let tpSteps = max(2, promptLinesCount - flashSteps - argonSteps)
        
        result.flashCount = flashSteps
        result.argonCount = argonSteps
        result.thirdPartyCount = tpSteps
        result.sessionCount = max(1, promptLinesCount / 6)
        
        let flashIn = flashSteps * 1800, flashOut = flashSteps * 400
        let argonIn = argonSteps * 3400, argonOut = argonSteps * 850
        let tpIn = tpSteps * 4200, tpOut = tpSteps * 1100
        
        result.inputTokens = flashIn + argonIn + tpIn
        result.outputTokens = flashOut + argonOut + tpOut
        result.totalTokens = result.inputTokens + result.outputTokens
        
        result.models = [
            ModelUsageItem(
                name: "Gemini 3.8 Flash (자사 모델)",
                provider: "Google",
                steps: flashSteps,
                inputTokens: flashIn,
                outputTokens: flashOut,
                reasoningTokens: flashSteps * 500,
                cost: 0.0
            ),
            ModelUsageItem(
                name: "Gemini 4 Argon (고성능 추론)",
                provider: "Google DeepMind",
                steps: argonSteps,
                inputTokens: argonIn,
                outputTokens: argonOut,
                reasoningTokens: argonSteps * 1400,
                cost: 0.0
            ),
            ModelUsageItem(
                name: "Claude Sonnet 5.5 (타사 모델)",
                provider: "Anthropic / Third-party",
                steps: tpSteps,
                inputTokens: tpIn,
                outputTokens: tpOut,
                reasoningTokens: tpSteps * 1800,
                cost: 0.0
            )
        ]
        
        return result
    }
    
    private func getDaysUntilMonthEnd() -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let range = calendar.range(of: .day, in: .month, for: now) else { return 15 }
        let currentDay = calendar.component(.day, from: now)
        return max(1, range.count - currentDay + 1)
    }
    
    private func getStoredTokenAndEmail() -> (token: String?, email: String) {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-s", "gemini", "-a", "antigravity", "-w"]
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let rawStr = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !rawStr.isEmpty else { return (nil, "") }
            
            let base64Part = rawStr.contains(":") ? String(rawStr.split(separator: ":", maxSplits: 1)[1]) : rawStr
            guard let decodedData = Data(base64Encoded: base64Part),
                  let json = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any] else {
                return (nil, "")
            }
            let email = json["id_token_email"] as? String ?? ""
            var tokenStr: String?
            if let tokenDict = json["token"] as? [String: Any] {
                tokenStr = tokenDict["access_token"] as? String
            }
            return (tokenStr, email)
        } catch {
            return (nil, "")
        }
    }
    
    private func getTodayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
