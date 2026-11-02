import SwiftUI

public struct DetailPopoverView: View {
    @ObservedObject var usageManager = UsageManager.shared
    @ObservedObject var settings = AppSettings.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack(spacing: 8) {
                Text("AI Usages")
                    .font(.system(size: 13, weight: .bold))
                
                Text(formatTime(usageManager.lastRefreshedAt))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Spacer()
                
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
                .help("새로고침")
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
            
            // MARK: - Footer (설정 메뉴를 별도 창/화면 없이 하단에 간결하게 통합)
            HStack(spacing: 8) {
                Text("자동 갱신:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                
                Picker("", selection: $settings.refreshIntervalSeconds) {
                    Text("15초").tag(15.0)
                    Text("30초").tag(30.0)
                    Text("1분").tag(60.0)
                    Text("5분").tag(300.0)
                }
                .pickerStyle(.segmented)
                .controlSize(.mini)
                .frame(width: 170)
                .onChange(of: settings.refreshIntervalSeconds) { _ in
                    usageManager.startTimer()
                }
                
                Spacer()
                
                Button("종료") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 10))
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
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
                Text("Go Subscription")
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                Text("• Renews in 6d 13h")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 6) {
                CleanProgressBar(
                    title: "5-hour window",
                    percent: windows.fiveHourRemainingPercent,
                    resetInfo: windows.fiveHourResetString
                )
                
                CleanProgressBar(
                    title: "Weekly",
                    percent: windows.weeklyRemainingPercent,
                    resetInfo: windows.weeklyResetString
                )
                
                CleanProgressBar(
                    title: "Monthly",
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
                Text("Google AI Pro")
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                Text("• Renews in 6d 13h")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.purple)
            }
            
            VStack(spacing: 6) {
                GroupSplitRow(
                    title: "Gemini Models",
                    weekly: groups.geminiWeeklyRemainingPercent,
                    weeklyInfo: groups.geminiWeeklyResetString,
                    fiveHour: groups.geminiFiveHourRemainingPercent,
                    fiveHourInfo: groups.geminiFiveHourResetString
                )
                
                GroupSplitRow(
                    title: "Claude & GPT",
                    weekly: groups.claudeWeeklyRemainingPercent,
                    weeklyInfo: "Quota available",
                    fiveHour: groups.claudeFiveHourRemainingPercent,
                    fiveHourInfo: "Quota available"
                )
                
                CleanProgressBar(
                    title: "Gemini 4 Argon",
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
    
    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                Text(String(format: "%.1f%% 남음", percent))
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Weekly:")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f%%", weekly))
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
                        Text("5-Hour:")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f%%", fiveHour))
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
