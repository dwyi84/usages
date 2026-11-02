import SwiftUI

public struct DetailPopoverView: View {
    @ObservedObject var usageManager = UsageManager.shared
    
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
                .help("환경설정 (구독 결제일/API 키)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            Divider()
            
            // MARK: - Body (탭 없이 위아래 순차 섹션, 스크롤바 일절 없음)
            VStack(spacing: 14) {
                // SECTION 1: OpenCode Go
                OpenCodeSectionView(snapshot: usageManager.openCodeSnapshot)
                
                Divider()
                
                // SECTION 2: Google AI Pro
                GoogleAISectionView(snapshot: usageManager.googleAISnapshot)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            Divider()
            
            // MARK: - Footer
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 5, height: 5)
                    Text("메뉴바 게이지: [왼쪽] OpenCode 잔여량 · [오른쪽] Google AI 잔여량")
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
        .frame(width: 440)
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

// MARK: - SECTION 1: OpenCode Go View
struct OpenCodeSectionView: View {
    let snapshot: ServiceUsageSnapshot
    var windows: OpenCodeWindows { snapshot.openCodeWindows }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section Header & Billing D-day
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .foregroundColor(.blue)
                        .font(.system(size: 13, weight: .bold))
                    Text("OpenCode Go")
                        .font(.system(size: 13, weight: .bold))
                }
                
                Spacer()
                
                // 구독료 결제일 / 만료일 뱃지 (자동 감지 안내)
                HStack(spacing: 4) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 9.5))
                    Text("구독 갱신: \(snapshot.billingDateString) (D-\(snapshot.daysUntilBilling))")
                        .font(.system(size: 10, weight: .semibold))
                    Text("자동")
                        .font(.system(size: 8.5, weight: .bold))
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(3)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.blue.opacity(0.12))
                .foregroundColor(.blue)
                .cornerRadius(6)
            }
            
            // 3대 윈도우 잔여량 바 (5시간, 주간, 월간)
            VStack(spacing: 7) {
                RemainingProgressRow(
                    label: "5시간 롤링 한도",
                    usedPercent: windows.rollingPercent,
                    infoText: windows.rollingResetString
                )
                
                RemainingProgressRow(
                    label: "주간 한도 (Weekly)",
                    usedPercent: windows.weeklyPercent,
                    infoText: windows.weeklyResetString
                )
                
                RemainingProgressRow(
                    label: "월간 쿼터 (Monthly)",
                    usedPercent: windows.monthlyPercent,
                    infoText: "결제일까지 \(snapshot.daysUntilBilling)일 남음"
                )
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // 요약 수치 행
            HStack(spacing: 8) {
                CompactMetric(title: "오늘 작업", value: "\(snapshot.todaySteps) 스텝")
                CompactMetric(title: "오늘 총 토큰", value: formatTokens(snapshot.todayTokens))
                CompactMetric(title: "캐시 읽기", value: formatTokens(snapshot.cacheReadTokens))
                CompactMetric(title: "주요 모델", value: snapshot.modelBreakdowns.first?.name ?? "deepseek")
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

// MARK: - SECTION 2: Google AI Pro View
struct GoogleAISectionView: View {
    let snapshot: ServiceUsageSnapshot
    var cats: GoogleAICategories { snapshot.googleCategories }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section Header & Billing D-day
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.system(size: 13, weight: .bold))
                    Text("Google AI Pro")
                        .font(.system(size: 13, weight: .bold))
                }
                
                Spacer()
                
                // 구독료 결제일 / 만료일 뱃지
                HStack(spacing: 4) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 9.5))
                    Text("구독 갱신: \(snapshot.billingDateString) (D-\(snapshot.daysUntilBilling))")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.purple.opacity(0.12))
                .foregroundColor(.purple)
                .cornerRadius(6)
            }
            
            // 3대 모델 카테고리별 잔여량 바 (자사, 아르곤, 타사)
            VStack(spacing: 7) {
                RemainingProgressRow(
                    label: "자사 모델 (Gemini Flash)",
                    usedPercent: cats.firstPartyPercent,
                    infoText: "\(max(0, cats.firstPartyLimit - cats.firstPartyUsed)) / \(cats.firstPartyLimit) 요청 남음"
                )
                
                RemainingProgressRow(
                    label: "아르곤 (Gemini 4 Argon 심층 추론)",
                    usedPercent: cats.argonPercent,
                    infoText: "\(max(0, cats.argonLimit - cats.argonUsed)) / \(cats.argonLimit) 요청 남음"
                )
                
                RemainingProgressRow(
                    label: "타사 모델 (Claude / Third-party)",
                    usedPercent: cats.thirdPartyPercent,
                    infoText: "\(max(0, cats.thirdPartyLimit - cats.thirdPartyUsed)) / \(cats.thirdPartyLimit) 요청 남음"
                )
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // 요약 수치 행
            HStack(spacing: 8) {
                let monthlyRemaining = max(0, Int(round(100.0 - cats.monthlyPercent)))
                CompactMetric(title: "월간 종합 잔여", value: "\(monthlyRemaining)% 남음")
                CompactMetric(title: "오늘 총 토큰", value: formatTokens(snapshot.todayTokens))
                CompactMetric(title: "일일 리셋", value: "자정 (00:00)")
                CompactMetric(title: "인증 상태", value: "연결됨")
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

// MARK: - Remaining Progress Row (남은 양 기준)
struct RemainingProgressRow: View {
    let label: String
    let usedPercent: Double
    let infoText: String
    
    var remainingPercent: Double {
        max(0.0, min(100.0, 100.0 - usedPercent))
    }
    
    // 남은 양 기준 색상 (충분: 초록, 보통: 주황, 위험: 빨강)
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
                Text(label)
                    .font(.system(size: 10.5, weight: .semibold))
                Spacer()
                Text("\(Int(round(remainingPercent)))% 남음")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(remainingPercent <= 15 ? .red : (remainingPercent <= 35 ? .orange : .primary))
            }
            
            // Remaining Gauge Bar (남은 양만큼 채워짐)
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
                Text(infoText)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
}

struct CompactMetric: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8.5))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 10.5, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
        .cornerRadius(6)
    }
}
