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
                        .padding(.vertical, 2)
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
            
            // MARK: - 2-Column Wide Grid Layout (2*1, 2*2, 2*3, 2*4)
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
                        case "opencode":
                            OpenCodeSectionView(snapshot: usageManager.openCodeSnapshot)
                        case "google_ai":
                            GoogleAISectionView(snapshot: usageManager.googleAISnapshot)
                        case "openrouter":
                            OpenRouterSectionView(snapshot: usageManager.openRouterSnapshot)
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
            
            Divider()
            
            // MARK: - Footer
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(L10n.autoRefresh)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $settings.refreshIntervalSeconds) {
                        Text(L10n.min1).tag(60.0)
                        Text(L10n.min3).tag(180.0)
                        Text(L10n.min5).tag(300.0)
                        Text(L10n.min15).tag(900.0)
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.mini)
                    .frame(width: 170)
                    .onChange(of: settings.refreshIntervalSeconds) { _ in
                        usageManager.startTimer()
                    }
                    
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
                        .padding(.vertical, 3)
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
                
                HStack {
                    Toggle(L10n.launchAtLogin, isOn: $launchAtLogin.isEnabled)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        updater.checkForUpdatesPresentingAlert()
                    }) {
                        Text(L10n.checkForUpdates)
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 580)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            uiState.openRouterKeyInput = settings.openRouterApiKey
        }
    }
    
    // MARK: - Hybrid Provider List View
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
                VStack(spacing: 4) {
                    ForEach(usageManager.registeredProviders) { provider in
                        HStack(spacing: 8) {
                            Button(action: {
                                usageManager.toggleProvider(id: provider.id)
                            }) {
                                Image(systemName: provider.isEnabled ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 11))
                                    .foregroundColor(provider.isEnabled ? .accentColor : .secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Text(provider.name)
                                .font(.system(size: 10.5, weight: provider.isEnabled ? .semibold : .regular))
                                .foregroundColor(provider.isEnabled ? .primary : .secondary)
                            
                            Spacer()
                            
                            if provider.isDetected {
                                Text(L10n.detectedBadge)
                                    .font(.system(size: 8, weight: .medium))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.green.opacity(0.12))
                                    .foregroundColor(.green)
                                    .cornerRadius(3)
                            } else {
                                Text(L10n.notDetectedBadge)
                                    .font(.system(size: 8))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.10))
                                    .foregroundColor(.secondary)
                                    .cornerRadius(3)
                            }
                        }
                        .padding(.vertical, 2)
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
                
                HStack(spacing: 4) {
                    Text("• \(windows.monthlyResetString)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.blue)
                    Text("(\(L10n.isKorean ? "API 자동" : "API Auto"))")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .help(L10n.autoSyncedTooltip)
            }
            
            // 2-Column Split: Left Quotas / Right Trend & Cost
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
                ProviderTrendView(trend: snapshot.trendSummary)
                    .frame(maxWidth: .infinity)
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
                ProviderTrendView(trend: snapshot.trendSummary)
                    .frame(maxWidth: .infinity)
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
                    
                    // Key status or Inline Edit field
                    if uiState.isEditingOpenRouterKey || !snapshot.isConnected {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.enterOpenRouterKey)
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                TextField("sk-or-...", text: $uiState.openRouterKeyInput)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                                
                                Button(L10n.save) {
                                    let cleaned = uiState.openRouterKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    settings.openRouterApiKey = cleaned
                                    settings.setProviderEnabled("openrouter", enabled: !cleaned.isEmpty)
                                    uiState.isEditingOpenRouterKey = false
                                    usageManager.reloadProviders()
                                    Task {
                                        await usageManager.refreshAll()
                                    }
                                }
                                .controlSize(.small)
                                
                                if snapshot.isConnected {
                                    Button(action: {
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
                            let key = settings.openRouterApiKey
                            let displayKey = key.count > 10 ? "\(key.prefix(8))...\(key.suffix(4))" : key
                            Text("API Key: \(displayKey)")
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                uiState.openRouterKeyInput = settings.openRouterApiKey
                                uiState.isEditingOpenRouterKey = true
                            }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "pencil")
                                    Text(L10n.isKorean ? "수정" : "Edit")
                                }
                                .font(.system(size: 9))
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
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
                ProviderTrendView(trend: snapshot.trendSummary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Shared Provider Trend View (Usage Trend & Daily Breakdown)
struct ProviderTrendView: View {
    let trend: UsageTrendSummary
    
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(L10n.usageTrend)
                    .font(.system(size: 9.5, weight: .bold))
                
                Spacer()
                
                MiniSparklineView(bars: trend.dailyBars)
            }
            
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
