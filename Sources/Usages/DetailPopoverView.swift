import SwiftUI

public final class PopoverNavigationState: ObservableObject {
    public static let shared = PopoverNavigationState()
    @Published public var showingSettings: Bool = false
    public init() {}
}

public struct DetailPopoverView: View {
    @ObservedObject var usageManager = UsageManager.shared
    @ObservedObject var navState = PopoverNavigationState.shared
    @ObservedObject var settings = AppSettings.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            if navState.showingSettings {
                // MARK: - In-Menu Settings View
                InMenuSettingsView()
            } else {
                // MARK: - Main Usage Dashboard View
                MainUsageDashboardView()
            }
        }
        .frame(width: 460)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Main Usage Dashboard View
struct MainUsageDashboardView: View {
    @ObservedObject var usageManager = UsageManager.shared
    @ObservedObject var navState = PopoverNavigationState.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "gauge.medium")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 15, weight: .bold))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("AI Usages")
                        .font(.system(size: 13, weight: .bold))
                    Text(formatTime(usageManager.lastRefreshedAt))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 새로고침 버튼
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
                
                // 메뉴 내 환경설정 전환 버튼
                Button(action: {
                    navState.showingSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("환경설정")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            Divider()
            
            // Body (스크롤바 없이 순차 2개 섹션)
            VStack(spacing: 14) {
                OpenCodeSubscriptionSection(snapshot: usageManager.openCodeSnapshot)
                Divider()
                GoogleAIProSection(snapshot: usageManager.googleAISnapshot)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            Divider()
            
            // Footer
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 5, height: 5)
                    Text("메뉴바 게이지: [왼쪽] OpenCode 월간 \(Int(usageManager.openCodeSnapshot.remainingPercent))% · [오른쪽] Google AI \(Int(usageManager.googleAISnapshot.remainingPercent))%")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("종료") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 10.5))
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss 갱신"
        return f.string(from: date)
    }
}

// MARK: - In-Menu Settings View (메뉴 내부에서 즉시 처리)
struct InMenuSettingsView: View {
    @ObservedObject var navState = PopoverNavigationState.shared
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with Back Button
            HStack {
                Button(action: {
                    navState.showingSettings = false
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("사용량 대시보드로 돌아가기")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                
                Spacer()
                
                Text("환경설정")
                    .font(.system(size: 13, weight: .bold))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 14) {
                // 1. 자동 동기화 상태
                VStack(alignment: .leading, spacing: 6) {
                    Text("실시간 동기화 상태")
                        .font(.system(size: 11, weight: .bold))
                    
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("로컬 서비스 100% 자동 연동 중")
                                .font(.system(size: 11, weight: .bold))
                            Text("OpenCode Go 및 Google AI Pro의 모든 실시간 쿼터와 리셋 주기가 시스템에서 안전하게 자동 동기화됩니다.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(6)
                }
                
                Divider()
                
                // 2. 자동 새로고침 주기
                VStack(alignment: .leading, spacing: 6) {
                    Text("백그라운드 자동 갱신 주기")
                        .font(.system(size: 11, weight: .bold))
                    
                    Picker("", selection: $settings.refreshIntervalSeconds) {
                        Text("15초").tag(15.0)
                        Text("30초 (권장)").tag(30.0)
                        Text("1분").tag(60.0)
                        Text("5분").tag(300.0)
                    }
                    .pickerStyle(.segmented)
                    
                    Text("메뉴바 배터리 바 및 쿼터 수치를 백그라운드에서 동기화하는 간격입니다.")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Spacer()
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button("완료") {
                    navState.showingSettings = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(height: 320)
    }
}

// MARK: - SECTION 1: OpenCode Go Subscription Section
struct OpenCodeSubscriptionSection: View {
    let snapshot: ServiceUsageSnapshot
    var windows: OpenCodeWindows { snapshot.openCodeWindows }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .foregroundColor(.blue)
                            .font(.system(size: 13, weight: .bold))
                        Text("Go Subscription")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text("Low cost coding models for everyone")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Renews badge
                HStack(spacing: 4) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 9.5))
                    Text("• Renews in 6d 13h")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.blue.opacity(0.12))
                .foregroundColor(.blue)
                .cornerRadius(6)
            }
            
            // 3대 윈도우 진행 바 (남은 양 기준)
            VStack(spacing: 7) {
                QuotaRemainingRow(
                    title: "5-hour window",
                    remainingPercent: windows.fiveHourRemainingPercent,
                    resetSubtitle: windows.fiveHourResetString
                )
                
                QuotaRemainingRow(
                    title: "Weekly",
                    remainingPercent: windows.weeklyRemainingPercent,
                    resetSubtitle: windows.weeklyResetString
                )
                
                QuotaRemainingRow(
                    title: "Monthly",
                    remainingPercent: windows.monthlyRemainingPercent,
                    resetSubtitle: windows.monthlyResetString
                )
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

// MARK: - SECTION 2: Google AI Pro Section
struct GoogleAIProSection: View {
    let snapshot: ServiceUsageSnapshot
    var groups: GoogleAIGroupLimits { snapshot.googleGroups }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                            .font(.system(size: 13, weight: .bold))
                        Text("Google AI Pro")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text("Gemini, Claude & Argon Model Lineup")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 9.5))
                    Text("• Renews in 6d 13h")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.purple.opacity(0.12))
                .foregroundColor(.purple)
                .cornerRadius(6)
            }
            
            // 3대 모델 그룹별 진행 바 (남은 양 기준)
            VStack(spacing: 8) {
                // 1. GEMINI MODELS
                GroupCard(
                    groupTitle: "GEMINI MODELS (Flash, Pro)",
                    weeklyPercent: groups.geminiWeeklyRemainingPercent,
                    weeklyReset: groups.geminiWeeklyResetString,
                    fiveHourPercent: groups.geminiFiveHourRemainingPercent,
                    fiveHourReset: groups.geminiFiveHourResetString
                )
                
                // 2. CLAUDE AND GPT MODELS
                GroupCard(
                    groupTitle: "CLAUDE AND GPT MODELS (Opus, Sonnet, GPT-OSS)",
                    weeklyPercent: groups.claudeWeeklyRemainingPercent,
                    weeklyReset: "Quota available",
                    fiveHourPercent: groups.claudeFiveHourRemainingPercent,
                    fiveHourReset: "Quota available"
                )
                
                // 3. GEMINI 4 ARGON
                SingleBarGroupCard(
                    groupTitle: "GEMINI 4 ARGON (Separate Pro Quota)",
                    weeklyPercent: groups.argonWeeklyRemainingPercent,
                    weeklyReset: groups.argonWeeklyResetString
                )
            }
        }
    }
}

// MARK: - Reusable UI Components (남은 양 기준 렌더링)
struct QuotaRemainingRow: View {
    let title: String
    let remainingPercent: Double
    let resetSubtitle: String
    
    var barColor: Color {
        if remainingPercent <= 15.0 {
            return .red
        } else if remainingPercent <= 35.0 {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                Spacer()
                Text(String(format: "%.1f%% 남음", remainingPercent))
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(remainingPercent <= 15 ? .red : (remainingPercent <= 35 ? .orange : .primary))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(NSColor.separatorColor).opacity(0.3))
                        .frame(height: 5.5)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * CGFloat(remainingPercent / 100.0)), height: 5.5)
                }
            }
            .frame(height: 5.5)
            
            HStack {
                Text(resetSubtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
}

struct GroupCard: View {
    let groupTitle: String
    let weeklyPercent: Double
    let weeklyReset: String
    let fiveHourPercent: Double
    let fiveHourReset: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(groupTitle)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Weekly:")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f%% 남음", weeklyPercent))
                            .font(.system(size: 10, weight: .bold))
                    }
                    MiniBar(percent: weeklyPercent)
                    Text(weeklyReset)
                        .font(.system(size: 8.5))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("5-Hour:")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f%% 남음", fiveHourPercent))
                            .font(.system(size: 10, weight: .bold))
                    }
                    MiniBar(percent: fiveHourPercent)
                    Text(fiveHourReset)
                        .font(.system(size: 8.5))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

struct SingleBarGroupCard: View {
    let groupTitle: String
    let weeklyPercent: Double
    let weeklyReset: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(groupTitle)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            
            HStack {
                Text("Argon Weekly Limit:")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2f%% 남음", weeklyPercent))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(weeklyPercent <= 35 ? .orange : .primary)
            }
            
            MiniBar(percent: weeklyPercent)
            
            HStack {
                Text(weeklyReset)
                    .font(.system(size: 8.5))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

struct MiniBar: View {
    let percent: Double
    
    var barColor: Color {
        if percent <= 15.0 {
            return .red
        } else if percent <= 40.0 {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(NSColor.separatorColor).opacity(0.3))
                    .frame(height: 4.5)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: max(0, geo.size.width * CGFloat(percent / 100.0)), height: 4.5)
            }
        }
        .frame(height: 4.5)
    }
}
