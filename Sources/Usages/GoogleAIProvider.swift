import Foundation

public final class GoogleAIProvider: @unchecked Sendable {
    public static let shared = GoogleAIProvider()
    
    private var cachedLimits = GoogleAIGroupLimits()
    private var isFetching = false
    
    public init() {}
    
    public func fetchUsageSnapshot() async -> ServiceUsageSnapshot {
        if let limits = await fetchLiveQuota() {
            cachedLimits = limits
        }
        
        let overallRemaining = cachedLimits.overallRemainingPercent
        
        return ServiceUsageSnapshot(
            service: .googleAI,
            planName: "Google AI Pro Plan",
            remainingPercent: overallRemaining,
            billingDateString: cachedLimits.nextBillingDateString,
            daysUntilBilling: cachedLimits.daysUntilBilling,
            status: overallRemaining <= 15 ? .critical : (overallRemaining <= 35 ? .warning : .normal),
            lastUpdated: Date(),
            googleGroups: cachedLimits
        )
    }
    
    private func fetchLiveQuota() async -> GoogleAIGroupLimits? {
        guard !isFetching else { return cachedLimits }
        isFetching = true
        defer { isFetching = false }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let agyPath = self.findAgyExecutable()
                guard let execPath = agyPath else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let process = Process()
                process.executableURL = URL(fileURLWithPath: execPath)
                process.arguments = ["--output-format", "json", "--print", "/usage"]
                
                var env = ProcessInfo.processInfo.environment
                let home = NSHomeDirectory()
                env["HOME"] = home
                env["PATH"] = "\(home)/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                process.environment = env
                
                let outPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = Pipe()
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    if let parsed = self.parseAgyJson(data: data) {
                        continuation.resume(returning: parsed)
                        return
                    }
                } catch {
                    // 실행 실패 시
                }
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func findAgyExecutable() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.local/bin/agy",
            "/usr/local/bin/agy",
            "/opt/homebrew/bin/agy"
        ]
        for c in candidates {
            if FileManager.default.isExecutableFile(atPath: c) {
                return c
            }
        }
        return nil
    }
    
    private func parseAgyJson(data: Data) -> GoogleAIGroupLimits? {
        struct AgyResponse: Decodable {
            struct Command: Decodable {
                let name: String?
                let data: UsageData?
            }
            struct UsageData: Decodable {
                let groups: [Group]?
            }
            struct Group: Decodable {
                let name: String
                let buckets: [Bucket]?
            }
            struct Bucket: Decodable {
                let id: String
                let name: String
                let window: String?
                let remaining_fraction: Double?
                let reset_time: String?
            }
            let command: Command?
        }
        
        guard let resp = try? JSONDecoder().decode(AgyResponse.self, from: data),
              let groups = resp.command?.data?.groups else {
            return nil
        }
        
        var result = cachedLimits
        
        for group in groups {
            let gName = group.name.lowercased()
            for bucket in group.buckets ?? [] {
                let fraction = bucket.remaining_fraction ?? 1.0
                let pct = max(0.0, min(100.0, fraction * 100.0))
                let countdown = formatCountdown(fraction: fraction, resetIso: bucket.reset_time)
                
                let bId = bucket.id.lowercased()
                
                if gName.contains("gemini models") || (!gName.contains("argon") && gName.contains("gemini")) {
                    if bId.contains("weekly") {
                        result.geminiWeeklyRemainingPercent = pct
                        result.geminiWeeklyResetString = countdown
                    } else if bId.contains("5h") || bId.contains("five") {
                        result.geminiFiveHourRemainingPercent = pct
                        result.geminiFiveHourResetString = countdown
                    }
                } else if gName.contains("claude") || gName.contains("3p") {
                    if bId.contains("weekly") {
                        result.claudeWeeklyRemainingPercent = pct
                        result.claudeWeeklyResetString = countdown
                    } else if bId.contains("5h") || bId.contains("five") {
                        result.claudeFiveHourRemainingPercent = pct
                        result.claudeFiveHourResetString = countdown
                    }
                } else if gName.contains("argon") {
                    result.argonWeeklyRemainingPercent = pct
                    result.argonWeeklyResetString = countdown
                }
            }
        }
        
        return result
    }
    
    private func formatCountdown(fraction: Double, resetIso: String?) -> String {
        if fraction >= 1.0 {
            return "Quota available"
        }
        guard let isoStr = resetIso, let date = ISO8601DateFormatter().date(from: isoStr) else {
            return "Quota available"
        }
        
        let diff = max(0, Int(date.timeIntervalSinceNow))
        let hours = diff / 3600
        let mins = (diff % 3600) / 60
        
        return "Refreshes in \(hours)h \(mins)m"
    }
}
