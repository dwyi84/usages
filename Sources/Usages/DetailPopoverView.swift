import SwiftUI

public final class DetailPopoverViewModel: ObservableObject {
    public static let shared = DetailPopoverViewModel()
    @Published public var selectedTab: ServiceType = .openCode
    public init() {}
}

public struct DetailPopoverView: View {
    @ObservedObject var usageManager = UsageManager.shared
    @ObservedObject var viewModel = DetailPopoverViewModel.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
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
                
                // 환경설정 버튼
                Button(action: {
                    openSettingsWindow()
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
            
            // MARK: - Main 2 Tabs (OpenCode Go vs Google AI Pro)
            HStack(spacing: 0) {
                TabButton(
                    title: "OpenCode Go",
                    icon: "cpu",
                    isSelected: viewModel.selectedTab == .openCode
                ) {
                    viewModel.selectedTab = .openCode
                }
                
                TabButton(
                    title: "Google AI Pro",
                    icon: "sparkles",
                    isSelected: viewModel.selectedTab == .googleAI
                ) {
                    viewModel.selectedTab = .googleAI
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            
            Divider()
            
            // MARK: - Tab Body
            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.selectedTab == .openCode {
                        OpenCodeDetailSection(snapshot: usageManager.openCodeSnapshot)
                    } else {
                        GoogleAIDetailSection(snapshot: usageManager.googleAISnapshot)
                    }
                }
                .padding(14)
            }
            .frame(maxHeight: 460)
            
            Divider()
            
            // MARK: - Footer
            HStack {
                // 아이콘 안내
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 5, height: 5)
                    Text("툴바 게이지: [왼쪽] OpenCode 월간 · [오른쪽] Google 월간")
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
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 380)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss 갱신"
        return f.string(from: date)
    }
    
    private func openSettingsWindow() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showPreferencesWindow(nil)
        }
    }
}

// MARK: - Custom Tab Button
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? Color(NSColor.selectedContentBackgroundColor).opacity(0.18) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - OpenCode Detail Section (5시간, 주간, 월간)
struct OpenCodeDetailSection: View {
    let snapshot: ServiceUsageSnapshot
    var windows: OpenCodeWindows { snapshot.openCodeWindows }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header summary
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OpenCode Go Plan")
                        .font(.system(size: 13, weight: .bold))
                    Text("안정적이고 빠른 코딩 모델 통합 플랜")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // D-day 뱃지
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 10))
                    Text("D-\(windows.daysUntilReset)일 후 갱신")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.12))
                .foregroundColor(.blue)
                .cornerRadius(12)
            }
            
            // 3대 윈도우 게이지 카드
            VStack(spacing: 10) {
                // 1) 5시간 롤링 윈도우
                UsageProgressRow(
                    title: "5시간 롤링 (5-Hour Window)",
                    percent: windows.rollingPercent,
                    subtitle: windows.rollingResetString,
                    accentColor: .green
                )
                
                Divider()
                
                // 2) 주간 한도 (Weekly Cap)
                UsageProgressRow(
                    title: "주간 한도 (Weekly Cap)",
                    percent: windows.weeklyPercent,
                    subtitle: windows.weeklyResetString,
                    accentColor: .teal
                )
                
                Divider()
                
                // 3) 월간 쿼터 (Monthly Quota) - 아이콘 연동
                UsageProgressRow(
                    title: "월간 쿼터 (Monthly Quota) ★툴바 연동",
                    percent: windows.monthlyPercent,
                    subtitle: "갱신까지 \(windows.daysUntilReset)일 남음 (\(windows.monthlyResetString))",
                    accentColor: .indigo
                )
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // 오늘 작업 통계 요약
            VStack(alignment: .leading, spacing: 6) {
                Text("오늘 작업량 & 토큰")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 10) {
                    StatPill(title: "오늘 작업", value: "\(snapshot.todaySteps) 스텝")
                    StatPill(title: "총 토큰", value: formatTokens(snapshot.todayTokens))
                    StatPill(title: "캐시 읽기", value: formatTokens(snapshot.cacheReadTokens))
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(8)
            
            // 모델별 내역
            if !snapshot.modelBreakdowns.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("사용 모델 현황")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    ForEach(snapshot.modelBreakdowns) { m in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.name)
                                    .font(.system(size: 11, weight: .medium))
                                Text("\(m.steps) 스텝 · \(formatTokens(m.totalTokens))")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(m.provider)
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
    
    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Google AI Pro Detail Section (자사, 아르곤, 타사)
struct GoogleAIDetailSection: View {
    let snapshot: ServiceUsageSnapshot
    var cats: GoogleAICategories { snapshot.googleCategories }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header summary
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Google AI Pro Plan")
                        .font(.system(size: 13, weight: .bold))
                    Text(snapshot.planName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // D-day 뱃지
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 10))
                    Text("D-\(cats.daysUntilReset)일 후 갱신")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.12))
                .foregroundColor(.purple)
                .cornerRadius(12)
            }
            
            // 3대 모델 카테고리별 분리 쿼터 게이지
            VStack(spacing: 10) {
                // 1) 자사 모델 (Gemini Flash)
                UsageProgressRow(
                    title: "자사 모델 (Gemini Flash)",
                    percent: cats.firstPartyPercent,
                    subtitle: "\(cats.firstPartyUsed) / \(cats.firstPartyLimit) 요청 소모",
                    accentColor: .blue
                )
                
                Divider()
                
                // 2) 아르곤 (Gemini 4 Argon)
                UsageProgressRow(
                    title: "아르곤 (Gemini 4 Argon 심층 추론)",
                    percent: cats.argonPercent,
                    subtitle: "\(cats.argonUsed) / \(cats.argonLimit) 요청 소모",
                    accentColor: .orange
                )
                
                Divider()
                
                // 3) 타사 모델 (Claude Sonnet/Opus, GPT-OSS)
                UsageProgressRow(
                    title: "타사 모델 (Claude / Third-party)",
                    percent: cats.thirdPartyPercent,
                    subtitle: "\(cats.thirdPartyUsed) / \(cats.thirdPartyLimit) 요청 소모",
                    accentColor: .purple
                )
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // 월간 종합 상태 카드
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("월간 종합 사용률 (툴바 아이콘 반영)")
                        .font(.system(size: 10.5, weight: .bold))
                    Text("일일 리셋 자정 00:00 · 월간 갱신 D-\(cats.daysUntilReset)")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(cats.monthlyPercent))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(cats.monthlyPercent >= 90 ? .red : (cats.monthlyPercent >= 70 ? .orange : .green))
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(8)
            
            // 모델 리스트
            if !snapshot.modelBreakdowns.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("카테고리별 활성 모델")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    ForEach(snapshot.modelBreakdowns) { m in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.name)
                                    .font(.system(size: 11, weight: .medium))
                                Text("\(m.steps) 스텝 · \(formatTokens(m.totalTokens)) 토큰")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(m.provider)
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
    
    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Reusable Progress Row
struct UsageProgressRow: View {
    let title: String
    let percent: Double
    let subtitle: String
    let accentColor: Color
    
    var remainingPercent: Double {
        max(0.0, min(100.0, 100.0 - percent))
    }
    
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("\(Int(round(percent)))% 소모")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(percent >= 90 ? .red : (percent >= 75 ? .orange : .primary))
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(NSColor.separatorColor).opacity(0.3))
                        .frame(height: 7)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(accentColor)
                        .frame(width: max(0, geo.size.width * CGFloat(percent / 100.0)), height: 7)
                }
            }
            .frame(height: 7)
            
            HStack {
                Text(subtitle)
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                Spacer()
                Text("잔여 \(Int(round(remainingPercent)))%")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct StatPill: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
