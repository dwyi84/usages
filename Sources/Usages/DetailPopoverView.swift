import SwiftUI

public final class DetailPopoverViewModel: ObservableObject {
    public static let shared = DetailPopoverViewModel()
    @Published public var selectedTab: ServiceType = .openCode
    public init() {}
}

public struct DetailPopoverView: View {
    @ObservedObject var usageManager = UsageManager.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var viewModel = DetailPopoverViewModel.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack(spacing: 10) {
                Image(systemName: "gauge.with.needle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("AI Usages")
                        .font(.system(size: 13, weight: .bold))
                    Text(formatTime(usageManager.lastRefreshedAt))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
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
            
            // MARK: - Segmented Tab Selector
            Picker("", selection: $viewModel.selectedTab) {
                HStack {
                    Image(systemName: "cpu")
                    Text("OpenCode Go")
                }.tag(ServiceType.openCode)
                
                HStack {
                    Image(systemName: "sparkles")
                    Text("Google AI Pro")
                }.tag(ServiceType.googleAI)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            // MARK: - Content Body
            ScrollView {
                VStack(spacing: 12) {
                    if viewModel.selectedTab == .openCode {
                        ServiceDetailCard(snapshot: usageManager.openCodeSnapshot)
                    } else {
                        ServiceDetailCard(snapshot: usageManager.googleAISnapshot)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .frame(maxHeight: 420)
            
            Divider()
            
            // MARK: - Footer Actions
            HStack {
                Text(settings.displayMode == .separateItems ? "2개 분리 툴바 모드" : "통합 툴바 모드")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("종료") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11))
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 360)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss 갱신"
        return f.string(from: date)
    }
    
    private func openSettingsWindow() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}

// MARK: - Service Detail Card
struct ServiceDetailCard: View {
    let snapshot: ServiceUsageSnapshot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: snapshot.service.defaultIconName)
                            .foregroundColor(.accentColor)
                            .font(.system(size: 13, weight: .bold))
                        Text(snapshot.service.rawValue)
                            .font(.system(size: 14, weight: .bold))
                    }
                    
                    Text(snapshot.planName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(snapshot.status.color)
                        .frame(width: 7, height: 7)
                    Text(snapshot.statusMessage)
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }
            
            // Big Battery Gauge Display
            VStack(spacing: 6) {
                HStack {
                    Text("사용량 잔여 게이지")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(round(snapshot.usedPercent)))% 소모 (\(Int(round(snapshot.remainingPercent)))% 남음)")
                        .font(.system(size: 11, weight: .bold))
                }
                
                // Battery Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.separatorColor).opacity(0.3))
                            .frame(height: 14)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [snapshot.status.color.opacity(0.8), snapshot.status.color],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * CGFloat(snapshot.remainingPercent / 100.0)), height: 14)
                    }
                }
                .frame(height: 14)
                
                HStack {
                    Text("리셋 주기:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(snapshot.resetTimeString)
                        .font(.system(size: 10, weight: .semibold))
                    Spacer()
                    Text("한도: \(Int(snapshot.maxLimit)) \(snapshot.unit)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Grid Metrics
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                MetricBox(title: "오늘 작업량", value: "\(snapshot.todaySteps) \(snapshot.unit)")
                MetricBox(title: "총 토큰", value: formatTokens(snapshot.todayTokens))
                MetricBox(title: "입력 / 출력", value: "\(formatTokens(snapshot.inputTokens)) / \(formatTokens(snapshot.outputTokens))")
                if snapshot.cacheReadTokens > 0 {
                    MetricBox(title: "캐시 읽기", value: formatTokens(snapshot.cacheReadTokens))
                } else {
                    MetricBox(title: "세션 수", value: "\(snapshot.sessionCount)회")
                }
            }
            
            // Model Breakdown Section
            if !snapshot.modelBreakdowns.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("모델별 사용 내역")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    ForEach(snapshot.modelBreakdowns) { m in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.name)
                                    .font(.system(size: 11, weight: .medium))
                                Text("\(m.steps)스텝 · \(formatTokens(m.totalTokens))")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if m.cost > 0 {
                                Text(String(format: "$%.3f", m.cost))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 3)
                        Divider()
                    }
                }
                .padding(12)
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

struct MetricBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
