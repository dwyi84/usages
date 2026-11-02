import SwiftUI

@MainActor
public final class SettingsViewModel: ObservableObject {
    public init() {}
}

@MainActor
public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var usageManager = UsageManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 15, weight: .bold))
                Text("Usages 환경설정")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
            }
            
            Divider()
            
            // Section 1: 자동 동기화 상태 (서비스 인증 설정 대체)
            VStack(alignment: .leading, spacing: 8) {
                Text("인증 및 동기화 상태")
                    .font(.system(size: 12, weight: .bold))
                
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("로컬 서비스 자동 연동 활성화됨")
                            .font(.system(size: 11, weight: .bold))
                        Text("OpenCode Go 및 Google AI Pro의 모든 인증과 실시간 쿼터를 시스템에서 자동으로 안전하게 읽어오고 있습니다 (수동 키 입력 불필요).")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(Color.green.opacity(0.08))
                .cornerRadius(6)
            }
            
            Divider()
            
            // Section 2: 자동 새로고침 주기
            VStack(alignment: .leading, spacing: 6) {
                Text("자동 새로고침 주기")
                    .font(.system(size: 12, weight: .bold))
                
                Picker("", selection: $settings.refreshIntervalSeconds) {
                    Text("15초").tag(15.0)
                    Text("30초 (권장)").tag(30.0)
                    Text("1분").tag(60.0)
                    Text("5분").tag(300.0)
                }
                .pickerStyle(.segmented)
            }
            
            Spacer()
            
            // Bottom Action Bar
            HStack {
                Spacer()
                Button("완료") {
                    if let window = NSApp.keyWindow {
                        window.close()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 400, height: 230)
    }
}
