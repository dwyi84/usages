import SwiftUI

public struct DetailPopoverView: View {
    @ObservedObject var usageManager = UsageManager.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var launchAtLogin = LaunchAtLoginManager.shared
    @ObservedObject var updater = UpdaterViewModel.shared
    
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
                
                // Update Pill if update is available
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
            .padding(.bottom, 8)
            
            Divider()
            
            // MARK: - Usage Sections (Simple & Minimal)
            VStack(spacing: 12) {
                // SECTION 1: OpenCode Go
                OpenCodeSectionView(snapshot: usageManager.openCodeSnapshot)
                
                Divider()
                
                // SECTION 2: Google AI Pro
                GoogleAISectionView(snapshot: usageManager.googleAISnapshot)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            Divider()
            
            // MARK: - Footer (설정, 커피 후원, 자동 시작, 업데이트 확인)
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(L10n.autoRefresh)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $settings.refreshIntervalSeconds) {
                        Text(L10n.sec15).tag(15.0)
                        Text(L10n.sec30).tag(30.0)
                        Text(L10n.min1).tag(60.0)
                        Text(L10n.min5).tag(300.0)
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
        .frame(width: 420)
        .background(Color(NSColor.windowBackgroundColor))
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
                
                Text("• \(windows.monthlyResetString)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.blue)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.googleAITitle)
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                Text("• \(groups.nextBillingDateString)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.purple)
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
