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
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)
            
            // MARK: - Top Segmented Tabs: [ 한도 쿼터 ] | [ 토큰 & 비용 ]
            Picker("", selection: $settings.selectedTabIndex) {
                Text(L10n.tabQuotas).tag(0)
                Text(L10n.tabTokenCost).tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            
            Divider()
            
            // MARK: - Main Content Area
            if settings.selectedTabIndex == 0 {
                // TAB 0: 한도 쿼터 (Quotas)
                quotasTabView
            } else {
                // TAB 1: 토큰 & 비용 (Tokens & Cost)
                tokenCostTabView
            }
            
            Divider()
            
            // MARK: - Footer (설정, 커피 후원, 자동 시작, 업데이트 확인)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 430)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            uiState.openRouterKeyInput = settings.openRouterApiKey
        }
    }
    
    // MARK: - Quotas Tab View
    private var quotasTabView: some View {
        VStack(spacing: 10) {
            let hasOC = settings.isProviderEnabled("opencode")
            let hasG = settings.isProviderEnabled("google_ai")
            
            if hasOC {
                OpenCodeSectionView(snapshot: usageManager.openCodeSnapshot)
            }
            
            if hasOC && hasG {
                Divider()
            }
            
            if hasG {
                GoogleAISectionView(snapshot: usageManager.googleAISnapshot)
            }
            
            if !hasOC && !hasG {
                VStack(spacing: 4) {
                    Text("활성화된 쿼터 프로바이더가 없습니다.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("아래 목록에서 사용할 프로바이더를 체크해 주세요.")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(.vertical, 16)
            }
            
            Divider()
            
            // 하이브리드 프로바이더 활성화 목록 (체크된 항목 상위 노출, 나머지 후속 리스트업)
            providerHybridListView
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    // MARK: - Hybrid Provider List View
    private var providerHybridListView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.isKorean ? "프로바이더 활성화 및 관리" : "Provider Activation & Discovery")
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
    
    // MARK: - Token & Cost Tab View
    private var tokenCostTabView: some View {
        VStack(spacing: 12) {
            let snap = usageManager.openRouterSnapshot
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.openRouterTitle)
                        .font(.system(size: 12, weight: .bold))
                    
                    Spacer()
                    
                    if snap.isConnected {
                        Text("• Active")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.green)
                    } else {
                        Text("• Not Connected")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                if snap.isConnected {
                    // Balance & Spend Matrix
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.balance)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(String(format: "$%.2f", snap.balanceUSD))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.accentColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider().frame(height: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.todaySpend)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(String(format: "$%.2f", snap.todaySpendUSD))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider().frame(height: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.monthSpend)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(String(format: "$%.2f", snap.monthSpendUSD))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    
                    // Token Breakdown
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.promptTokens)
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary)
                            Text("\(snap.promptTokens.formatted()) t")
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.completionTokens)
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary)
                            Text("\(snap.completionTokens.formatted()) t")
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.totalTokens)
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary)
                            Text("\(snap.totalTokens.formatted()) t")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                    }
                    .padding(.horizontal, 8)
                } else {
                    Text(L10n.noTokenProviders)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
            .cornerRadius(6)
            
            // Inline API Key Configuration
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.connectKey)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    SecureField(L10n.enterOpenRouterKey, text: $uiState.openRouterKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    
                    Button(L10n.save) {
                        settings.openRouterApiKey = uiState.openRouterKeyInput
                        settings.setProviderEnabled("openrouter", enabled: !uiState.openRouterKeyInput.isEmpty)
                        usageManager.reloadProviders()
                        Task {
                            await usageManager.refreshAll()
                        }
                        uiState.showKeySavedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            uiState.showKeySavedToast = false
                        }
                    }
                    .controlSize(.small)
                }
                
                if uiState.showKeySavedToast {
                    Text(L10n.isKorean ? "✓ 키가 저장되었습니다." : "✓ API Key saved.")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            .cornerRadius(6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}

// MARK: - OpenCode Go Section
struct OpenCodeSectionView: View {
    let snapshot: ServiceUsageSnapshot
    var windows: OpenCodeWindows { snapshot.openCodeWindows }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
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
        }
    }
}

// MARK: - Google AI Pro Section
struct GoogleAISectionView: View {
    let snapshot: ServiceUsageSnapshot
    var groups: GoogleAIGroupLimits { snapshot.googleGroups }
    @ObservedObject var uiState = PopoverUIState.shared
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.googleAITitle)
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                if settings.googleBillingDayOfMonth > 0 && !groups.nextBillingDateString.isEmpty {
                    Button(action: {
                        uiState.selectedBillingDay = settings.googleBillingDayOfMonth
                        uiState.isEditingGoogleBillingDay.toggle()
                    }) {
                        HStack(spacing: 3) {
                            Text("• \(groups.nextBillingDateString)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.purple)
                            Image(systemName: "pencil")
                                .font(.system(size: 8))
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
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.12))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.googleBillingTooltip)
                }
            }
            
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
            
            VStack(spacing: 6) {
                GroupSplitRow(
                    title: L10n.geminiModels,
                    weekly: groups.geminiWeeklyRemainingPercent,
                    weeklyInfo: groups.geminiWeeklyResetString,
                    fiveHour: groups.geminiFiveHourRemainingPercent,
                    fiveHourInfo: groups.geminiFiveHourResetString
                )
                
                GroupSplitRow(
                    title: L10n.claudeAndGpt,
                    weekly: groups.claudeWeeklyRemainingPercent,
                    weeklyInfo: groups.claudeWeeklyResetString,
                    fiveHour: groups.claudeFiveHourRemainingPercent,
                    fiveHourInfo: groups.claudeFiveHourResetString
                )
                
                CleanProgressBar(
                    title: L10n.geminiArgon,
                    percent: groups.argonWeeklyRemainingPercent,
                    resetInfo: groups.argonWeeklyResetString
                )
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
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
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                Text(formattedPercent)
                    .font(.system(size: 10, weight: .bold))
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
                    .font(.system(size: 8.5))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
}

struct GroupSplitRow: View {
    let title: String
    let weekly: Double
    let weeklyInfo: String
    let fiveHour: Double
    let fiveHourInfo: String
    
    private func fmt(_ val: Double) -> String {
        if val.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f%%", val)
        }
        return String(format: "%.2f%%", val)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(L10n.isKorean ? "주간:" : "Weekly:")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(fmt(weekly))
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    MiniSegmentLine(percent: weekly)
                    Text(weeklyInfo)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(L10n.isKorean ? "5시간:" : "5-Hour:")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(fmt(fiveHour))
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    MiniSegmentLine(percent: fiveHour)
                    Text(fiveHourInfo)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct MiniSegmentLine: View {
    let percent: Double
    
    var color: Color {
        if percent <= 15.0 { return .red }
        if percent <= 35.0 { return .orange }
        return .green
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(NSColor.separatorColor).opacity(0.25))
                    .frame(height: 3.5)
                
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: max(0, geo.size.width * CGFloat(percent / 100.0)), height: 3.5)
            }
        }
        .frame(height: 3.5)
    }
}
