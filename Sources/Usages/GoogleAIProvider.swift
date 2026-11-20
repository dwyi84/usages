import Foundation
import SQLite3

public final class GoogleAIProvider: @unchecked Sendable {
    public static let shared = GoogleAIProvider()
    
    struct KeychainCredentials: Equatable {
        let accessToken: String?
        let refreshToken: String?
        let expiresAt: Date?
        let clientId: String?
        let clientSecret: String?
    }
    
    private enum RestFetchOutcome {
        case success(GoogleAIGroupLimits)
        case rateLimited(HTTPURLResponse)
        case unauthorized
        case failed
    }
    
    private let stateLock = NSLock()
    private var cachedLimits = GoogleAIGroupLimits()
    private var isFetching = false
    private var lastAgyFullFetchDate: Date?
    private var rateLimitUntil: Date?
    private var cachedOAuthClient: (clientId: String, clientSecret: String)?
    private var cachedOAuthToken: (refreshToken: String, accessToken: String, expiresAt: Date)?
    
    public init() {}
    
    public var isAvailable: Bool {
        // Antigravity CLI가 있거나, Keychain에 gemini 토큰이 있으면 사용 가능
        return findAgyExecutable() != nil || hasKeychainToken()
    }
    
    public func fetchUsageSnapshot() async -> ServiceUsageSnapshot {
        guard isAvailable else {
            return ServiceUsageSnapshot(
                service: .googleAI,
                planName: "Google AI Pro Plan",
                remainingPercent: 0.0,
                billingDateString: "",
                daysUntilBilling: 0,
                status: .unknown,
                lastUpdated: Date(),
                isAvailable: false,
                googleGroups: GoogleAIGroupLimits(),
                trendSummary: UsageTrendSummary()
            )
        }
        
        // Rate limit 중이면 캐시 반환
        if let until = rateLimitUntil, Date() < until {
            let snapshot = buildSnapshot(status: .rateLimited)
            return snapshot
        }
        
        // 1. 직접 경량 REST API 호출 시도 (0.2~0.3초 초고속, 배터리 절약)
        if let directLimits = await fetchViaDirectRest() {
            cachedLimits = directLimits
            rateLimitUntil = nil
            
            // Argon 쿼터가 누락되었고 마지막 전체 fetch 후 30분 이상 경과 시 백그라운드로 agy 보완
            if shouldRunBackgroundAgy() {
                Task.detached { [weak self] in
                    await self?.fetchViaAgyCli()
                }
            }
            
            return buildSnapshot(status: .normal)
        }
        
        // REST가 429를 받아 rate limit 상태가 되었다면 agy 폴백도 건너뛴다.
        if let until = rateLimitUntil, Date() < until {
            return buildSnapshot(status: .rateLimited)
        }
        
        // 2. REST 실패 시 로컬 agy CLI 프로세스 폴백 시도
        if let cliLimits = await fetchViaAgyCli() {
            cachedLimits = cliLimits
            rateLimitUntil = nil
            return buildSnapshot(status: .normal)
        }
        
        // 3. 둘 다 실패 시 이전 캐시가 있으면 유지, 없으면 미감지 반환
        if lastAgyFullFetchDate != nil || cachedLimits.hasAnyKnownQuota {
            return buildSnapshot(status: .warning)
        }
        
        return ServiceUsageSnapshot(
            service: .googleAI,
            planName: "Google AI Pro Plan",
            remainingPercent: 0.0,
            billingDateString: "",
            daysUntilBilling: 0,
            status: .unknown,
            lastUpdated: Date(),
            isAvailable: false,
            googleGroups: GoogleAIGroupLimits(),
            trendSummary: fetchLocalUsageTrend()
        )
    }
    
    public static func calculateNextBilling(
        dayOfMonth: Int,
        now: Date = Date(),
        calendar baseCalendar: Calendar = Calendar(identifier: .gregorian)
    ) -> (dateString: String, daysRemaining: Int) {
        guard dayOfMonth >= 1 && dayOfMonth <= 31 else {
            return ("", 0)
        }
        let calendar = baseCalendar
        
        let currentDay = calendar.component(.day, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        var targetYear = currentYear
        var targetMonth = currentMonth
        
        // If the configured billing day already passed this month, the next
        // occurrence is next month. On the billing day itself we keep showing
        // "today" (the renewal time-of-day is not exposed by Google).
        if dayOfMonth < currentDay {
            targetMonth += 1
            if targetMonth > 12 {
                targetMonth = 1
                targetYear += 1
            }
        }
        
        guard let targetDate = billingDate(
            year: targetYear,
            month: targetMonth,
            day: dayOfMonth,
            calendar: calendar
        ) else {
            return ("", 0)
        }
        
        let diff = max(0, Int(targetDate.timeIntervalSince(now)))
        let totalHours = diff / 3600
        let days = totalHours / 24
        let hours = totalHours % 24
        
        let isKorean = L10n.isKorean
        let dateStr: String
        if days == 0 {
            if hours == 0 {
                dateStr = isKorean ? "오늘 리셋 (매월 \(dayOfMonth)일)" : "Resets today (\(dayOfMonth)th)"
            } else {
                dateStr = isKorean ? "\(hours)시간 후 리셋 (매월 \(dayOfMonth)일)" : "Resets in \(hours)h (\(dayOfMonth)th)"
            }
        } else {
            dateStr = isKorean ? "\(days)일 \(hours)시간 후 리셋 (매월 \(dayOfMonth)일)" : "Resets in \(days)d \(hours)h (\(dayOfMonth)th)"
        }
        return (dateStr, days)
    }
    
    /// Builds the start of the configured billing day, clamping to the last day
    /// of shorter months (e.g. day 31 in November must become Nov 30, not Dec 1).
    private static func billingDate(
        year: Int,
        month: Int,
        day: Int,
        calendar: Calendar
    ) -> Date? {
        guard let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let dayRange = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return nil
        }
        let clampedDay = min(day, dayRange.count)
        return calendar.date(from: DateComponents(year: year, month: month, day: clampedDay))
    }

    private func buildSnapshot(status: GaugeStatus) -> ServiceUsageSnapshot {
        let billingInfo = GoogleAIProvider.calculateNextBilling(dayOfMonth: AppSettings.shared.googleBillingDayOfMonth)
        var limits = cachedLimits
        limits.nextBillingDateString = billingInfo.dateString
        limits.daysUntilBilling = billingInfo.daysRemaining
        
        let overallRemaining = limits.overallRemainingPercent
        let resolvedStatus: GaugeStatus
        if status == .rateLimited {
            resolvedStatus = .rateLimited
        } else {
            resolvedStatus = overallRemaining <= 15 ? .critical : (overallRemaining <= 35 ? .warning : .normal)
        }
        
        let trend = fetchLocalUsageTrend()
        
        return ServiceUsageSnapshot(
            service: .googleAI,
            planName: "Google AI Pro Plan",
            remainingPercent: overallRemaining,
            billingDateString: limits.nextBillingDateString,
            daysUntilBilling: limits.daysUntilBilling,
            status: resolvedStatus,
            lastUpdated: Date(),
            isAvailable: isAvailable,
            googleGroups: limits,
            trendSummary: trend
        )
    }
    
    private func shouldRunBackgroundAgy() -> Bool {
        guard let last = lastAgyFullFetchDate else { return true }
        return Date().timeIntervalSince(last) > 1800 // 30분
    }
    
    // MARK: - Direct REST Engine
    private func fetchViaDirectRest() async -> GoogleAIGroupLimits? {
        guard let credentials = readKeychainCredentials() else { return nil }
        guard let token = await resolveAccessToken(from: credentials, forceRefresh: false) else { return nil }
        
        switch await performRestQuotaRequest(accessToken: token) {
        case .success(let limits):
            return limits
        case .rateLimited(let http):
            handleRateLimit(response: http)
            return nil
        case .unauthorized:
            guard let refreshToken = credentials.refreshToken, !refreshToken.isEmpty,
                  let refreshed = await resolveAccessToken(from: credentials, forceRefresh: true) else {
                return nil
            }
            switch await performRestQuotaRequest(accessToken: refreshed) {
            case .success(let limits):
                return limits
            case .rateLimited(let http):
                handleRateLimit(response: http)
                return nil
            case .unauthorized, .failed:
                return nil
            }
        case .failed:
            return nil
        }
    }
    
    private func performRestQuotaRequest(accessToken: String) async -> RestFetchOutcome {
        let endpoints = [
            "https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
            "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary"
        ]
        
        let projects = ["aicode-consumers", "default-cli-project", ""]
        var sawUnauthorized = false
        
        for urlStr in endpoints {
            guard let url = URL(string: urlStr) else { continue }
            
            for project in projects {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                
                #if arch(arm64)
                let arch = "arm64"
                #else
                let arch = "amd64"
                #endif
                request.setValue("antigravity/2.24.0 (aidev_client; os_type=darwin; arch=\(arch))", forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 6.0
                
                let bodyDict = project.isEmpty ? [:] : ["project": project]
                request.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict)
                
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let http = response as? HTTPURLResponse else { continue }
                    
                    if http.statusCode == 429 {
                        return .rateLimited(http)
                    }
                    
                    if http.statusCode == 401 {
                        sawUnauthorized = true
                        break
                    }
                    
                    if (200..<300).contains(http.statusCode) {
                        if let limits = parseRestQuotaJson(data: data) {
                            return .success(limits)
                        }
                    }
                } catch {
                    continue
                }
            }
        }
        
        return sawUnauthorized ? .unauthorized : .failed
    }
    
    private func handleRateLimit(response: HTTPURLResponse) {
        if let retryHeader = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(retryHeader) {
            rateLimitUntil = Date().addingTimeInterval(seconds)
        } else {
            rateLimitUntil = Date().addingTimeInterval(300) // 기본 5분 대기
        }
    }
    
    private func parseRestQuotaJson(data: Data) -> GoogleAIGroupLimits? {
        struct RestResponse: Decodable {
            struct Group: Decodable {
                let displayName: String?
                let buckets: [Bucket]?
            }
            struct Bucket: Decodable {
                let bucketId: String?
                let displayName: String?
                let window: String?
                let resetTime: String?
                let remainingFraction: Double?
            }
            let groups: [Group]?
        }
        
        guard let resp = try? JSONDecoder().decode(RestResponse.self, from: data),
              let groups = resp.groups, !groups.isEmpty else {
            return nil
        }
        
        var result = cachedLimits
        
        for g in groups {
            let gName = (g.displayName ?? "").lowercased()
            for b in g.buckets ?? [] {
                let fraction = b.remainingFraction ?? 1.0
                let pct = max(0.0, min(100.0, fraction * 100.0))
                let countdown = formatCountdown(resetIso: b.resetTime)
                let bId = (b.bucketId ?? "").lowercased()
                
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
                } else if gName.contains("argon") || bId.contains("argon") {
                    result.argonWeeklyRemainingPercent = pct
                    result.argonWeeklyResetString = countdown
                }
            }
        }
        
        return result
    }
    
    // MARK: - CLI Fallback Engine
    @discardableResult
    private func fetchViaAgyCli() async -> GoogleAIGroupLimits? {
        guard !isFetching else { return cachedLimits }
        isFetching = true
        defer { isFetching = false }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self, let execPath = self.findAgyExecutable() else {
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
                        self.stateLock.lock()
                        self.lastAgyFullFetchDate = Date()
                        self.cachedLimits = parsed
                        self.stateLock.unlock()
                        continuation.resume(returning: parsed)
                        return
                    }
                } catch {}
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
    
    private func hasKeychainToken() -> Bool {
        guard let creds = readKeychainCredentials() else { return false }
        return !(creds.accessToken ?? "").isEmpty || !(creds.refreshToken ?? "").isEmpty
    }
    
    private func readKeychainCredentials() -> KeychainCredentials? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "gemini", "-a", "antigravity", "-w"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let str = String(data: data, encoding: .utf8) else {
                return nil
            }
            return Self.parseKeychainCredentials(from: str)
        } catch {
            return nil
        }
    }
    
    static func parseKeychainCredentials(from rawString: String) -> KeychainCredentials? {
        var str = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !str.isEmpty else { return nil }
        if str.hasPrefix("go-keyring-base64:") {
            str = String(str.dropFirst("go-keyring-base64:".count))
        }
        guard let jsonData = Data(base64Encoded: str),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        let tokenDict = (json["token"] as? [String: Any]) ?? json
        let accessToken = (tokenDict["access_token"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let refreshToken = (tokenDict["refresh_token"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var expiresAt: Date?
        if let expiryStr = (tokenDict["expiry"] as? String) ?? (tokenDict["expires_at"] as? String) {
            expiresAt = ISO8601Parser.date(from: expiryStr)
        } else if let expiresEpoch = tokenDict["expires_at"] as? Double {
            expiresAt = Date(timeIntervalSince1970: expiresEpoch)
        }
        
        let clientId = ((json["client_id"] as? String) ?? (tokenDict["client_id"] as? String))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = ((json["client_secret"] as? String) ?? (tokenDict["client_secret"] as? String))?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !(accessToken ?? "").isEmpty || !(refreshToken ?? "").isEmpty else {
            return nil
        }
        return KeychainCredentials(
            accessToken: accessToken?.isEmpty == true ? nil : accessToken,
            refreshToken: refreshToken?.isEmpty == true ? nil : refreshToken,
            expiresAt: expiresAt,
            clientId: clientId?.isEmpty == true ? nil : clientId,
            clientSecret: clientSecret?.isEmpty == true ? nil : clientSecret
        )
    }
    
    static func extractOAuthClients(fromBinaryData data: Data) -> [(clientId: String, clientSecret: String)] {
        guard let text = String(data: data, encoding: .isoLatin1), !text.isEmpty else {
            return []
        }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        guard let idRegex = try? NSRegularExpression(pattern: #"[0-9]{12,13}-[a-z0-9]{32}\.apps\.googleusercontent\.com"#),
              let secretRegex = try? NSRegularExpression(pattern: #"GOCSPX-[A-Za-z0-9_-]{28}"#) else {
            return []
        }
        let nsText = text as NSString
        let ids = idRegex.matches(in: text, range: fullRange).map { nsText.substring(with: $0.range) }
        let secrets = secretRegex.matches(in: text, range: fullRange).map { nsText.substring(with: $0.range) }
        
        var pairs = Array(zip(ids, secrets)).map { (clientId: $0.0, clientSecret: $0.1) }
        pairs.sort { lhs, rhs in
            let lPreferred = lhs.clientId.hasPrefix("1071")
            let rPreferred = rhs.clientId.hasPrefix("1071")
            if lPreferred != rPreferred {
                return lPreferred
            }
            return false
        }
        return pairs
    }
    
    static func oauthClientCandidates(
        credentials: KeychainCredentials,
        cachedClient: (clientId: String, clientSecret: String)?,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        agyBinaryData: Data? = nil
    ) -> [(clientId: String, clientSecret: String)] {
        var candidates: [(clientId: String, clientSecret: String)] = []
        
        func add(_ cid: String?, _ csec: String?) {
            guard let cid = cid?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let csec = csec?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !cid.isEmpty, !csec.isEmpty else {
                return
            }
            if !candidates.contains(where: { $0.clientId == cid && $0.clientSecret == csec }) {
                candidates.append((clientId: cid, clientSecret: csec))
            }
        }
        
        add(credentials.clientId, credentials.clientSecret)
        add(environment["AIUSAGES_GOOGLE_CLIENT_ID"], environment["AIUSAGES_GOOGLE_CLIENT_SECRET"])
        if let cachedClient {
            add(cachedClient.clientId, cachedClient.clientSecret)
        }
        if let agyBinaryData {
            for pair in extractOAuthClients(fromBinaryData: agyBinaryData) {
                add(pair.clientId, pair.clientSecret)
            }
        }
        return candidates
    }
    
    private func resolveAccessToken(
        from credentials: KeychainCredentials,
        forceRefresh: Bool,
        now: Date = Date()
    ) async -> String? {
        guard let refreshToken = credentials.refreshToken, !refreshToken.isEmpty else {
            return credentials.accessToken
        }
        
        if !forceRefresh {
            let cached = stateLock.withLock { cachedOAuthToken }
            
            if let cached,
               cached.refreshToken == refreshToken,
               cached.expiresAt > now.addingTimeInterval(60) {
                return cached.accessToken
            }
            
            if let accessToken = credentials.accessToken, !accessToken.isEmpty,
               let expiresAt = credentials.expiresAt,
               expiresAt > now.addingTimeInterval(60) {
                return accessToken
            }
        }
        
        if let refreshed = await refreshAccessToken(credentials: credentials, refreshToken: refreshToken, now: now) {
            return refreshed
        }
        
        // A cached/keychain access token may still work even if refresh fails (e.g. offline/transient).
        return forceRefresh ? nil : credentials.accessToken
    }
    
    private func refreshAccessToken(
        credentials: KeychainCredentials,
        refreshToken: String,
        now: Date
    ) async -> String? {
        let currentCachedClient = stateLock.withLock { cachedOAuthClient }
        
        var agyData: Data?
        if let agyPath = findAgyExecutable() {
            let resolvedURL = URL(fileURLWithPath: agyPath).resolvingSymlinksInPath()
            agyData = try? Data(contentsOf: resolvedURL, options: [.mappedIfSafe])
        }
        
        var candidates = Self.oauthClientCandidates(
            credentials: credentials,
            cachedClient: currentCachedClient,
            agyBinaryData: agyData
        )
        if candidates.isEmpty {
            candidates = [("", "")]
        }
        
        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else {
            return nil
        }
        
        for candidate in candidates {
            var request = URLRequest(url: tokenURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 10.0
            
            let body: [String: String] = [
                "client_id": candidate.clientId,
                "client_secret": candidate.clientSecret,
                "refresh_token": refreshToken,
                "grant_type": "refresh_token"
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let newAccess = json["access_token"] as? String,
                      !newAccess.isEmpty else {
                    continue
                }
                
                let expiresIn = (json["expires_in"] as? Double)
                    ?? (json["expires_in"] as? Int).map(Double.init)
                    ?? 3600.0
                let expiresAt = now.addingTimeInterval(expiresIn)
                
                stateLock.withLock {
                    cachedOAuthToken = (refreshToken: refreshToken, accessToken: newAccess, expiresAt: expiresAt)
                    if !candidate.clientId.isEmpty && !candidate.clientSecret.isEmpty {
                        cachedOAuthClient = candidate
                    }
                }
                
                return newAccess
            } catch {
                continue
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
                let countdown = formatCountdown(resetIso: bucket.reset_time)
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
                } else if gName.contains("argon") || bId.contains("argon") {
                    result.argonWeeklyRemainingPercent = pct
                    result.argonWeeklyResetString = countdown
                }
            }
        }
        
        return result
    }
    
    private func formatCountdown(resetIso: String?) -> String {
        guard let date = ISO8601Parser.date(from: resetIso) else {
            return L10n.quotaAvailable
        }
        
        let diff = max(0, Int(date.timeIntervalSinceNow))
        let totalHours = diff / 3600
        let mins = (diff % 3600) / 60
        
        if totalHours >= 24 {
            let days = totalHours / 24
            let remainingHours = totalHours % 24
            if L10n.isKorean {
                return "\(days)일 \(remainingHours)시간 후 리셋"
            }
            return "Resets in \(days)d \(remainingHours)h"
        } else {
            if L10n.isKorean {
                return "\(totalHours)시간 \(mins)분 후 리셋"
            }
            return "Resets in \(totalHours)h \(mins)m"
        }
    }
    
    private func fetchLocalUsageTrend() -> UsageTrendSummary {
        let dbPath = ("~/.gemini/antigravity-cli/conversation_summaries.db" as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: dbPath) else { return UsageTrendSummary() }
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return UsageTrendSummary() }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 1_000)
        
        // `last_modified_time` is stored as UTC ("...+00:00"). Grouping with
        // plain date() bucketed usage by UTC day, while the UI compares against
        // local calendar days. In KST every event between 00:00 and 08:59 was
        // attributed to the previous day. Convert to local before grouping.
        let query = """
        SELECT 
            date(last_modified_time, 'localtime') as day, 
            sum(step_count) as steps 
        FROM conversation_summaries 
        WHERE datetime(last_modified_time) >= datetime('now', '-35 days') 
        GROUP BY day 
        ORDER BY day ASC;
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return UsageTrendSummary() }
        defer { sqlite3_finalize(stmt) }
        
        var stepsByDate: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let dStr = sqlite3_column_text(stmt, 0) {
                let day = String(cString: dStr)
                let steps = Int(sqlite3_column_int64(stmt, 1))
                stepsByDate[day] = steps
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
        
        // Antigravity only exposes step counts locally. Do not invent tokens or
        // dollar amounts from a steps→tokens multiplier: that produced numbers
        // that could never match any real usage figure. Report steps as steps.
        let todaySteps = stepsByDate[todayStr] ?? 0
        let todayTokens = todaySteps
        let todaySpend = 0.0
        
        let yesterdaySteps = stepsByDate[yesterdayStr] ?? 0
        let yesterdayTokens = yesterdaySteps
        let yesterdaySpend = 0.0
        
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
                let steps = stepsByDate[dStr] ?? 0
                last30DaysSpend += 0.0
                last30DaysTokens += steps
                dailyTokenCounts.append(steps)
                dailyPoints.append(DailyUsagePoint(dateString: dStr, dateLabel: lStr, spendUSD: 0.0, tokens: steps, normalized: 0.0))
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
        let logQuery = "SELECT title, step_count FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 1;"
        var logStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, logQuery, -1, &logStmt, nil) == SQLITE_OK {
            if sqlite3_step(logStmt) == SQLITE_ROW {
                if let tStr = sqlite3_column_text(logStmt, 0) {
                    let title = String(cString: tStr)
                    let steps = Int(sqlite3_column_int64(logStmt, 1))
                    let cleanTitle = title.count > 20 ? "\(title.prefix(18))..." : title
                    recentLog = L10n.isKorean ? "최근 세션: \(cleanTitle) (\(steps) steps)" : "Recent: \(cleanTitle) (\(steps) steps)"
                }
            }
            sqlite3_finalize(logStmt)
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
            recentActivityLog: recentLog,
            metricUnit: .steps,
            costAvailable: false
        )
    }
}
