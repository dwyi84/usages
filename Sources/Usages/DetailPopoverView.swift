import SwiftUI

public struct DetailPopoverView: View {
    @ObservedObject var usageManager = UsageManager.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var launchAtLogin = LaunchAtLoginManager.shared
    @ObservedObject var updater = UpdaterViewModel.shared
    @ObservedObject var uiState = PopoverUIState.shared
    
    private let coffeeURL = URL(string: "https://buymeacoffee.com/dwyi84d")!
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack(spacing: 8) {
                Text(L10n.appTitle)
                    .font(.system(size: 13, weight: .bold))
                
                Text("v\(UpdaterViewModel.currentVersion) · \(formatTime(usageManager.lastRefreshedAt))")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 체크 주기 (가장 위쪽 헤더로 이동)
                HStack(spacing: 3) {
                    Text(L10n.checkInterval)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $settings.refreshIntervalSeconds) {
                        Text(L10n.min1).tag(60.0)
                        Text(L10n.min3).tag(180.0)
                        Text(L10n.min5).tag(300.0)
                        Text(L10n.min15).tag(900.0)
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.mini)
                    .frame(width: 140)
                    .onChange(of: settings.refreshIntervalSeconds) { _ in
                        usageManager.startTimer()
                    }
                }
                
                // CopyNinja style Header Update Check Button
                Button(action: {
                    updater.checkForUpdatesPresentingAlert()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 8.5))
                        Text(L10n.checkForUpdates)
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(Color(NSColor.separatorColor).opacity(0.12))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(L10n.checkForUpdates)
                
                if updater.updateState == .updateAvailable, let newVer = updater.pendingUpdateVersion {
                    Button(action: {
                        updater.presentUpdateConfirmation()
                    }) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.orange).frame(width: 6, height: 6)
                            Text("v\(newVer) \(L10n.updateAvailable)")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: {
                    Task {
                        await usageManager.refreshAll()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(usageManager.isRefreshing ? 360 : 0))
                        .animation(usageManager.isRefreshing ? Animation.linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: usageManager.isRefreshing)
                }
                .buttonStyle(.plain)
                .help(L10n.refreshTooltip)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // MARK: - Scrollable Content Body (적당한 높이값 및 내부 스크롤 처리로 잘림 방지)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    let activeOrder = settings.providerOrder.filter { settings.isProviderEnabled($0) }
                    
                    if activeOrder.isEmpty {
                        VStack(spacing: 4) {
                            Text(L10n.isKorean ? "활성화된 프로바이더가 없습니다." : "No active providers.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(L10n.isKorean ? "아래 '프로바이더 활성화 및 관리'에서 사용할 서비스를 체크해 주세요." : "Check the services you want to track below.")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .padding(.vertical, 24)
                    } else {
                        ForEach(activeOrder, id: \.self) { id in
                            switch id {
                            case "codex":
                                GenericAISectionView(
                                    providerId: "codex",
                                    providerName: "Codex",
                                    envKeyName: "OPENAI_API_KEY",
                                    keyPrefix: "sk-",
                                    isDetected: ProviderDetector.isDetected(id: "codex")
                                )
                            case "claude":
                                GenericAISectionView(
                                    providerId: "claude",
                                    providerName: "Claude",
                                    envKeyName: "ANTHROPIC_API_KEY",
                                    keyPrefix: "sk-ant-",
                                    isDetected: ProviderDetector.isDetected(id: "claude")
                                )
                            case "cursor":
                                CursorSectionView()
                            case "google_ai":
                                GoogleAISectionView(snapshot: usageManager.googleAISnapshot)
                            case "opencode":
                                OpenCodeSectionView(snapshot: usageManager.openCodeSnapshot)
                            case "openrouter":
                                OpenRouterSectionView(snapshot: usageManager.openRouterSnapshot)
                            case "copilot":
                                GenericAISectionView(
                                    providerId: "copilot",
                                    providerName: "Copilot",
                                    envKeyName: "GITHUB_TOKEN",
                                    keyPrefix: "ghp_",
                                    isDetected: ProviderDetector.isDetected(id: "copilot")
                                )
                            case "perplexity":
                                GenericAISectionView(
                                    providerId: "perplexity",
                                    providerName: "Perplexity",
                                    envKeyName: "PERPLEXITY_API_KEY",
                                    keyPrefix: "pplx-",
                                    isDetected: ProviderDetector.isDetected(id: "perplexity")
                                )
                            case "deepseek":
                                GenericAISectionView(
                                    providerId: "deepseek",
                                    providerName: "DeepSeek",
                                    envKeyName: "DEEPSEEK_API_KEY",
                                    keyPrefix: "sk-",
                                    isDetected: ProviderDetector.isDetected(id: "deepseek")
                                )
                            default:
                                EmptyView()
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 하이브리드 프로바이더 활성화 및 관리 (접기/펼치기)
                    providerHybridListView
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(maxHeight: 460)
            
            Divider()
            
            // MARK: - Footer (로그인 시 자동 시작, 후원하기, 종료 - 상시 고정 노출)
            HStack(spacing: 8) {
                Toggle(L10n.launchAtLogin, isOn: $launchAtLogin.isEnabled)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Buy Me a Coffee Button
                Link(destination: coffeeURL) {
                    HStack(spacing: 4) {
                        Text("☕")
                            .font(.system(size: 10))
                        Text(L10n.buyMeACoffee)
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color(red: 1.0, green: 0.87, blue: 0.0))
                    .foregroundColor(.black)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                
                Button(L10n.quit) {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 10))
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 480)
        .frame(maxHeight: 560)
        .background(Color(NSColor.windowBackgroundColor))
        .popover(isPresented: $uiState.showDetailedTrendPopover, arrowEdge: .leading) {
            if let summary = uiState.selectedTrendSummary {
                DetailedTrendPopoverView(title: uiState.selectedTrendTitle, summary: summary)
            }
        }
    }
    
    // MARK: - Hybrid Provider List View (3*3 Grid with Toggle Switches)
    private var providerHybridListView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.isKorean ? "프로바이더 활성화 및 관리" : "Provider Activation & Management")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        uiState.showProviderSettings.toggle()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        AppDelegate.shared?.updatePopoverSize()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: uiState.showProviderSettings ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                        Text(uiState.showProviderSettings ? (L10n.isKorean ? "접기" : "Collapse") : (L10n.isKorean ? "펼치기" : "Manage"))
                            .font(.system(size: 9.5))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            if uiState.showProviderSettings {
                let columns = [
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6)
                ]
                
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(usageManager.registeredProviders) { provider in
                        ProviderGridTile(provider: provider)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(6)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}

// MARK: - OpenCode Go Section (2-Column Card: Left Quotas / Right Trend & Cost)
struct OpenCodeSectionView: View {
    let snapshot: ServiceUsageSnapshot
    var windows: OpenCodeWindows { snapshot.openCodeWindows }
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Card Header
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Button(action: { settings.moveProviderUp(id: "opencode") }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(settings.providerOrder.first != "opencode" ? .primary : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.providerOrder.first == "opencode")
                    .help(L10n.moveUp)
                    
                    Button(action: { settings.moveProviderDown(id: "opencode") }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(settings.providerOrder.last != "opencode" ? .primary : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.providerOrder.last == "opencode")
                    .help(L10n.moveDown)
                }
                
                Text(L10n.openCodeTitle)
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                Text("• \(windows.monthlyResetString)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            // 2-Column Split: Left Quotas / Right Trend & Cost
            if snapshot.isAvailable {
                HStack(alignment: .top, spacing: 10) {
                    // Left: 한도 쿼터 게이지
                    VStack(spacing: 6) {
                        CleanProgressBar(
                            title: L10n.fiveHourWindow,
                            percent: windows.fiveHourRemainingPercent,
                            resetInfo: windows.fiveHourResetString
                        )
                        
                        CleanProgressBar(
                            title: L10n.weekly,
                            percent: windows.weeklyRemainingPercent,
                            resetInfo: windows.weeklyResetString
                        )
                        
                        CleanProgressBar(
                            title: L10n.monthly,
                            percent: windows.monthlyRemainingPercent,
                            resetInfo: windows.monthlyResetString
                        )
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .frame(maxWidth: .infinity)
                    
                    // Right: 토큰 트렌드 & 코스트 환산
                    ProviderTrendView(title: L10n.openCodeTitle, trend: snapshot.trendSummary)
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.isKorean ? "OpenCode Go 인증 미감지" : "OpenCode Go Credentials Not Detected")
                            .font(.system(size: 10, weight: .bold))
                        Text(L10n.isKorean ? "로컬 OpenCode 인증 파일(~/.local/share/opencode/opencode.db)이 없거나 로그인되지 않았습니다." : "Local OpenCode credentials (~/.local/share/opencode/opencode.db) not found or not signed in.")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
        }
    }
}

// MARK: - Google AI Pro Section (2-Column Card: Left Quotas / Right Trend & Cost)
struct GoogleAISectionView: View {
    let snapshot: ServiceUsageSnapshot
    var groups: GoogleAIGroupLimits { snapshot.googleGroups }
    @ObservedObject var uiState = PopoverUIState.shared
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Card Header
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Button(action: { settings.moveProviderUp(id: "google_ai") }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(settings.providerOrder.first != "google_ai" ? .primary : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.providerOrder.first == "google_ai")
                    .help(L10n.moveUp)
                    
                    Button(action: { settings.moveProviderDown(id: "google_ai") }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(settings.providerOrder.last != "google_ai" ? .primary : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.providerOrder.last == "google_ai")
                    .help(L10n.moveDown)
                }
                
                Text(L10n.googleAITitle)
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                if settings.googleBillingDayOfMonth > 0 && !groups.nextBillingDateString.isEmpty {
                    Text("• \(groups.nextBillingDateString)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.purple)
                }
            }
            
            // Inline reset day editor
            if uiState.isEditingGoogleBillingDay {
                HStack(spacing: 6) {
                    Text(L10n.billingDayPrompt)
                        .font(.system(size: 10, weight: .medium))
                    
                    Picker("", selection: $uiState.selectedBillingDay) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)\(L10n.dayUnit)").tag(day)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 65)
                    .controlSize(.small)
                    
                    Button(L10n.save) {
                        settings.googleBillingDayOfMonth = uiState.selectedBillingDay
                        uiState.isEditingGoogleBillingDay = false
                        Task {
                            await UsageManager.shared.refreshAll()
                        }
                    }
                    .controlSize(.small)
                    
                    if settings.googleBillingDayOfMonth > 0 {
                        Button(L10n.reset) {
                            settings.googleBillingDayOfMonth = 0
                            uiState.isEditingGoogleBillingDay = false
                            Task {
                                await UsageManager.shared.refreshAll()
                            }
                        }
                        .controlSize(.small)
                    }
                    
                    Button(action: {
                        uiState.isEditingGoogleBillingDay = false
                    }) {
                        Text("✕")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(Color.purple.opacity(0.08))
                .cornerRadius(6)
            }
            
            // 2-Column Split: Left Quotas (5h -> 주간 -> 월간) / Right Trend & Cost
            if snapshot.isAvailable {
                HStack(alignment: .top, spacing: 10) {
                    // Left: 5시간 -> 주간 -> 월간 순서
                    VStack(spacing: 5) {
                        // 1. 5시간 윈도우
                        HStack {
                            Text(L10n.fiveHourWindow)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        CleanProgressBar(
                            title: L10n.geminiModels,
                            percent: groups.geminiFiveHourRemainingPercent,
                            resetInfo: groups.geminiFiveHourResetString
                        )
                        CleanProgressBar(
                            title: L10n.claudeAndGpt,
                            percent: groups.claudeFiveHourRemainingPercent,
                            resetInfo: groups.claudeFiveHourResetString
                        )
                        
                        Divider().padding(.vertical, 1)
                        
                        // 2. 주간 한도
                        HStack {
                            Text(L10n.weekly)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        CleanProgressBar(
                            title: L10n.geminiModels,
                            percent: groups.geminiWeeklyRemainingPercent,
                            resetInfo: groups.geminiWeeklyResetString
                        )
                        CleanProgressBar(
                            title: L10n.claudeAndGpt,
                            percent: groups.claudeWeeklyRemainingPercent,
                            resetInfo: groups.claudeWeeklyResetString
                        )
                        CleanProgressBar(
                            title: L10n.geminiArgon,
                            percent: groups.argonWeeklyRemainingPercent,
                            resetInfo: groups.argonWeeklyResetString
                        )
                        
                        Divider().padding(.vertical, 1)
                        
                        // 3. 월간 리셋
                        HStack {
                            Text(L10n.monthly)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            if settings.googleBillingDayOfMonth > 0 && !groups.nextBillingDateString.isEmpty {
                                Button(action: {
                                    uiState.selectedBillingDay = settings.googleBillingDayOfMonth
                                    uiState.isEditingGoogleBillingDay.toggle()
                                }) {
                                    HStack(spacing: 2) {
                                        Text(groups.nextBillingDateString)
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.purple)
                                        Image(systemName: "pencil")
                                            .font(.system(size: 7.5))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .help(L10n.googleBillingTooltip)
                            } else {
                                Button(action: {
                                    let currentDay = Calendar.current.component(.day, from: Date())
                                    uiState.selectedBillingDay = currentDay
                                    uiState.isEditingGoogleBillingDay.toggle()
                                }) {
                                    Text(L10n.setBillingDay)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.purple)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.purple.opacity(0.12))
                                        .cornerRadius(3)
                                }
                                .buttonStyle(.plain)
                                .help(L10n.googleBillingTooltip)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .frame(maxWidth: .infinity)
                    
                    // Right: 토큰 트렌드 & 코스트 환산
                    ProviderTrendView(title: L10n.googleAITitle, trend: snapshot.trendSummary)
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.isKorean ? "Google AI Pro (Antigravity) 미감지" : "Google AI Pro (Antigravity) Not Detected")
                            .font(.system(size: 10, weight: .bold))
                        Text(L10n.isKorean ? "Antigravity CLI(agy) 또는 Google AI 계정 키체인 토큰이 설치/로그인되어 있지 않습니다." : "Antigravity CLI (agy) or Google AI Keychain token is not installed or signed in.")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
        }
    }
}

// MARK: - OpenRouter Section View (2-Column Card: Left Balance & Key / Right Trend & Cost)
struct OpenRouterSectionView: View {
    let snapshot: TokenCostSnapshot
    @ObservedObject var uiState = PopoverUIState.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var usageManager = UsageManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Card Header
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Button(action: { settings.moveProviderUp(id: "openrouter") }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(settings.providerOrder.first != "openrouter" ? .primary : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.providerOrder.first == "openrouter")
                    .help(L10n.moveUp)
                    
                    Button(action: { settings.moveProviderDown(id: "openrouter") }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(settings.providerOrder.last != "openrouter" ? .primary : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.providerOrder.last == "openrouter")
                    .help(L10n.moveDown)
                }
                
                Text(L10n.openRouterTitle)
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                if snapshot.isConnected {
                    Text(String(format: "%@: $%.2f", L10n.balance, snapshot.balanceUSD))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.accentColor)
                } else {
                    Text("• " + (L10n.isKorean ? "키 미설정" : "Key Not Set"))
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
            }
            
            // 2-Column Split: Left Balance & Key Config / Right Trend & Cost
            HStack(alignment: .top, spacing: 10) {
                // Left: 잔액 & API 키 상태 (저장 후 깔끔하게 숨김 및 수정 대비)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.balance)
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary)
                            Text(String(format: "$%.2f", snapshot.balanceUSD))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.accentColor)
                        }
                        
                        Spacer()
                        
                        if snapshot.isConnected {
                            Text(L10n.isKorean ? "✓ 연동됨" : "✓ Active")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.green)
                        } else {
                            Text(L10n.isKorean ? "키 등록 필요" : "Setup Required")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Divider()
                    
                    // Key status or Inline Edit field (보안 강화: 저장 후 키 노출 절대 불가, 수정 시 빈 입력창으로 대체)
                    if uiState.isEditingOpenRouterKey || !settings.hasOpenRouterKey {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(L10n.enterOpenRouterKey)
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if settings.hasOpenRouterKey {
                                    Button(L10n.deleteKey) {
                                        settings.deleteOpenRouterKey()
                                        uiState.openRouterKeyInput = ""
                                        uiState.isEditingOpenRouterKey = false
                                        usageManager.reloadProviders()
                                        Task {
                                            await usageManager.refreshAll()
                                        }
                                    }
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.red.opacity(0.85))
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            HStack(spacing: 4) {
                                TextField("sk-or-...", text: $uiState.openRouterKeyInput)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                                
                                Button(L10n.save) {
                                    let cleaned = uiState.openRouterKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !cleaned.isEmpty {
                                        settings.saveOpenRouterKey(cleaned)
                                        settings.setProviderEnabled("openrouter", enabled: true)
                                    }
                                    uiState.openRouterKeyInput = ""
                                    uiState.isEditingOpenRouterKey = false
                                    usageManager.reloadProviders()
                                    Task {
                                        await usageManager.refreshAll()
                                    }
                                }
                                .controlSize(.small)
                                .disabled(uiState.openRouterKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                
                                if settings.hasOpenRouterKey {
                                    Button(action: {
                                        uiState.openRouterKeyInput = ""
                                        uiState.isEditingOpenRouterKey = false
                                    }) {
                                        Text("✕")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 10))
                                Text(L10n.keySavedSecurely)
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                uiState.openRouterKeyInput = "" // 평문 불러오지 않고 신규 입력 준비
                                uiState.isEditingOpenRouterKey = true
                            }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 8))
                                    Text(L10n.replaceKey)
                                }
                                .font(.system(size: 9))
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help(L10n.replaceKey)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .frame(maxWidth: .infinity)
                
                // Right: 토큰 트렌드 & 코스트 환산
                ProviderTrendView(title: L10n.openRouterTitle, trend: snapshot.trendSummary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Shared Provider Trend View (Usage Trend & Daily Breakdown)
struct ProviderTrendView: View {
    let title: String
    let trend: UsageTrendSummary
    @ObservedObject var uiState = PopoverUIState.shared
    
    var body: some View {
        VStack(spacing: 5) {
            Button(action: {
                uiState.selectedTrendTitle = title
                uiState.selectedTrendSummary = trend
                uiState.showDetailedTrendPopover = true
            }) {
                HStack {
                    HStack(spacing: 3) {
                        Text(L10n.usageTrend)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.primary)
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 7.5))
                            .foregroundColor(.accentColor)
                    }
                    
                    Spacer()
                    
                    MiniSparklineView(bars: trend.dailyBars)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.isKorean ? "클릭하여 30일 상세 트렌드 차트 및 X/Y축 통계 보기" : "Click to view detailed 30-day trend chart")
            
            Divider()
            
            // Today
            HStack {
                Text(L10n.today)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(formatCurrency(trend.todaySpendUSD)) · \(formatTokenCount(trend.todayTokens))")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
            }
            
            // Yesterday
            HStack {
                Text(L10n.yesterday)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(formatCurrency(trend.yesterdaySpendUSD)) · \(formatTokenCount(trend.yesterdayTokens))")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
            }
            
            // Last 30 Days
            HStack {
                Text(L10n.last30Days)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(formatCurrency(trend.last30DaysSpendUSD)) · \(formatTokenCount(trend.last30DaysTokens))")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
            }
            
            Divider()
            
            // Daily Avg & Peak
            HStack {
                Text(L10n.dailyAverage)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(formatCurrency(trend.dailyAvgSpendUSD)) · \(formatTokenCount(trend.dailyAvgTokens))")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            if !trend.peakDateLabel.isEmpty && trend.peakTokens > 0 {
                HStack {
                    Text(L10n.peakDay)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(trend.peakDateLabel): \(formatTokenCount(trend.peakTokens))")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }
            
            // Recent Session / Activity Log Badge
            if !trend.recentActivityLog.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 7.5))
                        .foregroundColor(.secondary)
                    Text(trend.recentActivityLog)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2.5)
                .background(Color(NSColor.separatorColor).opacity(0.08))
                .cornerRadius(4)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
    
    private func formatCurrency(_ usd: Double) -> String {
        return String(format: "$%.2f", usd)
    }
    
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000_000 {
            return String(format: "%.1fB tokens", Double(count) / 1_000_000_000.0)
        } else if count >= 1_000_000 {
            return String(format: "%.1fM tokens", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK tokens", Double(count) / 1_000.0)
        } else {
            return "\(count) tokens"
        }
    }
}

// MARK: - Detailed Usage Trend Popover View (Enlarged with X and Y Axes)
struct DetailedTrendPopoverView: View {
    let title: String
    let summary: UsageTrendSummary
    @ObservedObject var uiState = PopoverUIState.shared
    
    var dailyPoints: [DailyUsagePoint] {
        summary.dailyPoints
    }
    
    var maxTokens: Int {
        let maxVal = dailyPoints.map { $0.tokens }.max() ?? 0
        return max(maxVal, 1)
    }
    
    var peakPoint: DailyUsagePoint? {
        dailyPoints.max(by: { $0.tokens < $1.tokens })
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Title Header with close button
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text("\(title) \(L10n.detailedTrendTitle)")
                        .font(.system(size: 13, weight: .bold))
                    Text("(최근 30일)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    uiState.showDetailedTrendPopover = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            
            // 4 Summary Metrics Cards
            HStack(spacing: 8) {
                MetricCard(
                    title: L10n.totalTokens,
                    value: formatTokens(summary.last30DaysTokens),
                    color: .primary
                )
                
                MetricCard(
                    title: L10n.isKorean ? "총 환산비용" : "Total Cost",
                    value: String(format: "$%.2f", summary.last30DaysSpendUSD),
                    color: .green
                )
                
                MetricCard(
                    title: L10n.dailyAverage,
                    value: formatTokens(summary.last30DaysTokens / max(dailyPoints.count, 1)),
                    color: .accentColor
                )
                
                MetricCard(
                    title: L10n.peakDay,
                    value: peakPoint != nil && (peakPoint?.tokens ?? 0) > 0 ? "\(peakPoint!.dateLabel): \(formatTokens(peakPoint!.tokens))" : "-",
                    color: .orange
                )
            }
            
            // Interactive Inspection Banner
            HStack {
                if let idx = uiState.hoveredTrendIndex, idx < dailyPoints.count {
                    let pt = dailyPoints[idx]
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                        Text("\(pt.dateString) (\(pt.dateLabel))")
                            .font(.system(size: 10.5, weight: .bold))
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(formatTokens(pt.tokens)) tokens")
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(.accentColor)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(String(format: "$%.2f", pt.spendUSD))
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.point.up.left")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(L10n.trendChartTip)
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.separatorColor).opacity(0.1))
            .cornerRadius(5)
            
            // Detailed Chart Area with Y-Axis & X-Axis
            VStack(spacing: 4) {
                HStack(alignment: .bottom, spacing: 6) {
                    // Y-Axis Labels
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(formatTokens(maxTokens))
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTokens(maxTokens / 2))
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("0")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 44, height: 110)
                    
                    // Chart Columns Plot
                    ZStack(alignment: .bottomLeading) {
                        // Horizontal Grid lines (100%, 50%, 0%)
                        VStack(spacing: 0) {
                            Divider().opacity(0.5)
                            Spacer()
                            Divider().opacity(0.25)
                            Spacer()
                            Divider().opacity(0.6)
                        }
                        .frame(height: 110)
                        
                        // 30 Bars
                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(0..<dailyPoints.count, id: \.self) { idx in
                                let pt = dailyPoints[idx]
                                let heightFraction = CGFloat(pt.tokens) / CGFloat(maxTokens)
                                let isHovered = uiState.hoveredTrendIndex == idx
                                
                                VStack(spacing: 0) {
                                    Spacer(minLength: 0)
                                    
                                    if pt.tokens > 0 {
                                        RoundedRectangle(cornerRadius: 1.5)
                                            .fill(isHovered ? Color.orange : Color.accentColor)
                                            .frame(height: max(4.0, heightFraction * 106.0))
                                            .shadow(color: isHovered ? Color.orange.opacity(0.4) : Color.clear, radius: 2)
                                    } else {
                                        Circle()
                                            .fill(isHovered ? Color.orange : Color.accentColor.opacity(0.3))
                                            .frame(width: 3, height: 3)
                                            .padding(.bottom, 1)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: 110, alignment: .bottom)
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    if hovering {
                                        uiState.hoveredTrendIndex = idx
                                    } else if uiState.hoveredTrendIndex == idx {
                                        uiState.hoveredTrendIndex = nil
                                    }
                                }
                            }
                        }
                        .frame(height: 110)
                    }
                    .frame(height: 110)
                }
                
                // X-Axis (Date ticks)
                HStack(spacing: 0) {
                    Spacer().frame(width: 50) // offset for Y-axis
                    
                    // 5 date ticks: index 0 (29일 전), 7, 14, 21, 29 (오늘)
                    HStack {
                        if !dailyPoints.isEmpty {
                            Text(dailyPoints[0].dateLabel)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            if dailyPoints.count > 7 {
                                Text(dailyPoints[7].dateLabel)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            if dailyPoints.count > 14 {
                                Text(dailyPoints[14].dateLabel)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            if dailyPoints.count > 21 {
                                Text(dailyPoints[21].dateLabel)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            Text(dailyPoints.last?.dateLabel ?? "")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .padding(16)
        .frame(width: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000_000 {
            return String(format: "%.1fB", Double(count) / 1_000_000_000.0)
        } else if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 8.5))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - Mini Sparkline View (30 Daily Bars / Dots)
struct MiniSparklineView: View {
    let bars: [Double]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<min(30, bars.count), id: \.self) { idx in
                let val = bars[idx]
                if val <= 0.001 {
                    Circle()
                        .fill(Color.accentColor.opacity(0.35))
                        .frame(width: 2.5, height: 2.5)
                } else {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.accentColor)
                        .frame(width: 2.5, height: max(4.0, CGFloat(val) * 13.0))
                }
            }
        }
        .frame(height: 13, alignment: .bottom)
    }
}

// MARK: - Clean Minimal Progress Components
struct CleanProgressBar: View {
    let title: String
    let percent: Double
    let resetInfo: String
    
    var color: Color {
        if percent <= 15.0 { return .red }
        if percent <= 35.0 { return .orange }
        return .green
    }
    
    var formattedPercent: String {
        if percent.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f%% %@", percent, L10n.remaining)
        }
        return String(format: "%.2f%% %@", percent, L10n.remaining)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                Spacer()
                Text(formattedPercent)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(NSColor.separatorColor).opacity(0.25))
                        .frame(height: 4.5)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(percent / 100.0)), height: 4.5)
                }
            }
            .frame(height: 4.5)
            
            HStack {
                Text(resetInfo)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
}

// MARK: - Provider Grid Tile (Compact 3*3 Switch Layout)
struct ProviderGridTile: View {
    let provider: ProviderDescriptor
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var usageManager = UsageManager.shared
    
    var isEnabled: Bool {
        settings.isProviderEnabled(provider.id)
    }
    
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(provider.isDetected ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 5.5, height: 5.5)
                .help(provider.isDetected ? L10n.detectedBadge : L10n.notDetectedBadge)
            
            Text(provider.name)
                .font(.system(size: 9.5, weight: isEnabled ? .semibold : .regular))
                .foregroundColor(isEnabled ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 2)
            
            Toggle("", isOn: Binding(
                get: { self.isEnabled },
                set: { _ in
                    usageManager.toggleProvider(id: provider.id)
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(isEnabled ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor).opacity(0.4))
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isEnabled ? Color.accentColor.opacity(0.25) : Color(NSColor.separatorColor).opacity(0.15), lineWidth: 0.5)
        )
    }
}

// MARK: - Generic AI Provider Section View (Codex, Claude, Copilot, Perplexity, DeepSeek)
struct GenericAISectionView: View {
    let providerId: String
    let providerName: String
    let envKeyName: String
    let keyPrefix: String
    let isDetected: Bool
    
    @ObservedObject var uiState = PopoverUIState.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var usageManager = UsageManager.shared
    
    var hasKey: Bool {
        settings.hasKey(id: providerId)
    }
    
    var isEditing: Bool {
        uiState.editingProviderKeyId == providerId || (!hasKey && !isDetected)
    }
    
    var trend: UsageTrendSummary {
        UsageTrendSummary(
            todaySpendUSD: 0.0,
            todayTokens: 0,
            yesterdaySpendUSD: 0.0,
            yesterdayTokens: 0,
            last30DaysSpendUSD: 0.0,
            last30DaysTokens: 0,
            dailyBars: Array(repeating: 0.05, count: 30),
            dailyPoints: [],
            dailyAvgSpendUSD: 0.0,
            dailyAvgTokens: 0,
            peakDateLabel: "",
            peakTokens: 0,
            recentActivityLog: (isDetected || hasKey) ? (L10n.isKorean ? "세션 연결됨 · 활동 대기" : "Session Connected · Ready") : (L10n.isKorean ? "API 연동 필요" : "Setup Required")
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Card Header
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Button(action: { settings.moveProviderUp(id: providerId) }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(settings.providerOrder.first != providerId ? .primary : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.providerOrder.first == providerId)
                    .help(L10n.moveUp)
                    
                    Button(action: { settings.moveProviderDown(id: providerId) }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(settings.providerOrder.last != providerId ? .primary : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.providerOrder.last == providerId)
                    .help(L10n.moveDown)
                }
                
                Text(providerName)
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                if hasKey || isDetected {
                    Text("• " + (L10n.isKorean ? "연동됨" : "Active"))
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    Text("• " + (L10n.isKorean ? "키 미설정" : "Key Not Set"))
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
            }
            
            // 2-Column Split: Left Status & Key Config / Right Trend
            HStack(alignment: .top, spacing: 10) {
                // Left Column: Status & Write-only Key input
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.isKorean ? "연동 상태" : "Status")
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary)
                            Text(hasKey ? (L10n.isKorean ? "API 키 연동" : "API Key Linked") : (isDetected ? (L10n.isKorean ? "환경변수/로컬 감지" : "Detected Locally") : (L10n.isKorean ? "미설정" : "Not Linked")))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(hasKey || isDetected ? .primary : .secondary)
                        }
                        
                        Spacer()
                        
                        if hasKey || isDetected {
                            Text(L10n.isKorean ? "✓ 정상" : "✓ OK")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.green)
                        } else {
                            Text(L10n.isKorean ? "키 등록 필요" : "Setup Required")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Divider()
                    
                    // Key Configuration
                    if isEditing {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(L10n.isKorean ? "API 키 입력 (\(envKeyName))" : "Enter API Key (\(envKeyName))")
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if hasKey {
                                    Button(L10n.deleteKey) {
                                        settings.deleteKey(id: providerId)
                                        uiState.genericKeyInput = ""
                                        uiState.editingProviderKeyId = nil
                                        usageManager.reloadProviders()
                                    }
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.red.opacity(0.85))
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            HStack(spacing: 4) {
                                TextField(keyPrefix + "...", text: $uiState.genericKeyInput)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                                
                                Button(L10n.save) {
                                    let cleaned = uiState.genericKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !cleaned.isEmpty {
                                        settings.saveKey(id: providerId, key: cleaned)
                                    }
                                    uiState.genericKeyInput = ""
                                    uiState.editingProviderKeyId = nil
                                    usageManager.reloadProviders()
                                }
                                .controlSize(.small)
                                .disabled(uiState.genericKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                
                                if hasKey || isDetected {
                                    Button(action: {
                                        uiState.genericKeyInput = ""
                                        uiState.editingProviderKeyId = nil
                                    }) {
                                        Text("✕")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else {
                        // Key is registered - secure write-only presentation
                        HStack {
                            Label(L10n.isKorean ? "API Key 안전 등록됨" : "API Key Securely Stored", systemImage: "checkmark.shield.fill")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.green)
                            
                            Spacer()
                            
                            Button(action: {
                                uiState.genericKeyInput = ""
                                uiState.editingProviderKeyId = providerId
                            }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 8))
                                    Text(L10n.isKorean ? "새 키 등록" : "Update")
                                        .font(.system(size: 9))
                                }
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help(L10n.isKorean ? "기존 키는 노출되지 않으며 새 키로 안전하게 대체됩니다" : "Safely overwrite with a new key")
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                
                // Right Column: Usage Trend View
                ProviderTrendView(title: providerName, trend: trend)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Cursor Section View
struct CursorSectionView: View {
    @ObservedObject var uiState = PopoverUIState.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var usageManager = UsageManager.shared
    
    var isDetected: Bool {
        ProviderDetector.isDetected(id: "cursor")
    }
    
    var hasKey: Bool {
        settings.hasKey(id: "cursor")
    }
    
    var isEditing: Bool {
        uiState.editingProviderKeyId == "cursor"
    }
    
    var trend: UsageTrendSummary {
        UsageTrendSummary(
            todaySpendUSD: 0.0,
            todayTokens: 0,
            yesterdaySpendUSD: 0.0,
            yesterdayTokens: 0,
            last30DaysSpendUSD: 0.0,
            last30DaysTokens: 0,
            dailyBars: Array(repeating: 0.05, count: 30),
            dailyPoints: [],
            dailyAvgSpendUSD: 0.0,
            dailyAvgTokens: 0,
            peakDateLabel: "",
            peakTokens: 0,
            recentActivityLog: isDetected ? (L10n.isKorean ? "Cursor.app 로컬 설치 감지됨" : "Cursor.app Installed") : (L10n.isKorean ? "Cursor 미설치" : "Cursor Not Installed")
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Card Header
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Button(action: { settings.moveProviderUp(id: "cursor") }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(settings.providerOrder.first != "cursor" ? .primary : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.providerOrder.first == "cursor")
                    .help(L10n.moveUp)
                    
                    Button(action: { settings.moveProviderDown(id: "cursor") }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(settings.providerOrder.last != "cursor" ? .primary : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.providerOrder.last == "cursor")
                    .help(L10n.moveDown)
                }
                
                Text("Cursor")
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                if isDetected || hasKey {
                    Text("• " + (L10n.isKorean ? "감지됨" : "Detected"))
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    Text("• " + (L10n.isKorean ? "미설치" : "Not Installed"))
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
            }
            
            // 2-Column Split: Left IDE Info & Token / Right Trend
            HStack(alignment: .top, spacing: 10) {
                // Left Column
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.isKorean ? "IDE 상태" : "IDE Status")
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary)
                            Text(isDetected ? (L10n.isKorean ? "Cursor 활성화" : "Cursor Active") : (L10n.isKorean ? "Cursor 미설치" : "Not Found"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isDetected ? .primary : .secondary)
                        }
                        
                        Spacer()
                        
                        if isDetected {
                            Text(L10n.isKorean ? "✓ 설치됨" : "✓ Installed")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.green)
                        } else {
                            Text(L10n.isKorean ? "미감지" : "Missing")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    if isEditing {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(L10n.isKorean ? "Cursor 토큰 입력 (선택사항)" : "Cursor Token (Optional)")
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if hasKey {
                                    Button(L10n.deleteKey) {
                                        settings.deleteKey(id: "cursor")
                                        uiState.genericKeyInput = ""
                                        uiState.editingProviderKeyId = nil
                                        usageManager.reloadProviders()
                                    }
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.red.opacity(0.85))
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            HStack(spacing: 4) {
                                TextField("token...", text: $uiState.genericKeyInput)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                                
                                Button(L10n.save) {
                                    let cleaned = uiState.genericKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !cleaned.isEmpty {
                                        settings.saveKey(id: "cursor", key: cleaned)
                                    }
                                    uiState.genericKeyInput = ""
                                    uiState.editingProviderKeyId = nil
                                    usageManager.reloadProviders()
                                }
                                .controlSize(.small)
                                .disabled(uiState.genericKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                
                                Button(action: {
                                    uiState.genericKeyInput = ""
                                    uiState.editingProviderKeyId = nil
                                }) {
                                    Text("✕")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if hasKey {
                        HStack {
                            Label(L10n.isKorean ? "토큰 안전 등록됨" : "Token Stored", systemImage: "checkmark.shield.fill")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.green)
                            
                            Spacer()
                            
                            Button(action: {
                                uiState.genericKeyInput = ""
                                uiState.editingProviderKeyId = "cursor"
                            }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 8))
                                    Text(L10n.isKorean ? "토큰 변경" : "Update")
                                        .font(.system(size: 9))
                                }
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        HStack {
                            Text(isDetected ? (L10n.isKorean ? "로컬 /Applications/Cursor.app 연동" : "Linked with /Applications/Cursor.app") : (L10n.isKorean ? "Cursor 설치 시 자동 연동됩니다" : "Auto-detected on Cursor install"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                uiState.genericKeyInput = ""
                                uiState.editingProviderKeyId = "cursor"
                            }) {
                                Text(L10n.isKorean ? "토큰 설정" : "Set Token")
                                    .font(.system(size: 9))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                
                // Right Column: Usage Trend View
                ProviderTrendView(title: "Cursor", trend: trend)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
        )
    }
}
