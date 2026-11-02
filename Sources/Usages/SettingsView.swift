import SwiftUI

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var googleBillingDay: Int
    @Published public var openCodeKeyInput: String
    @Published public var googleKeyInput: String
    @Published public var saveStatusMessage: String = ""
    
    // OpenCode의 자동 동기화된 결제일 읽기 전용 표시
    public var openCodeAutoDetectedDate: String {
        let oc = UsageManager.shared.openCodeSnapshot
        return oc.billingDateString.isEmpty ? "API 동기화 중..." : "\(oc.billingDateString) (D-\(oc.daysUntilBilling))"
    }
    
    public init() {
        self.googleBillingDay = AppSettings.shared.googleBillingDay
        self.openCodeKeyInput = AppSettings.shared.openCodeApiKey
        self.googleKeyInput = AppSettings.shared.googleApiKey
    }
}

@MainActor
public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var usageManager = UsageManager.shared
    @ObservedObject var viewModel: SettingsViewModel
    
    public init() {
        self.viewModel = SettingsViewModel()
    }
    
    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
            
            // Section 1: 구독료 결제일 설정 (자동 vs 수동 명확한 구분)
            VStack(alignment: .leading, spacing: 10) {
                Text("구독료 결제일 (만료/갱신일) 연동")
                    .font(.system(size: 12, weight: .bold))
                
                // 1) OpenCode Go (자동 제공 - 직접 설정 불가 안내)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 13))
                        .padding(.top, 2)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("OpenCode Go")
                                .font(.system(size: 11, weight: .bold))
                            Text("서버 API 자동 연동")
                                .font(.system(size: 9.5, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.12))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                        
                        Text("서버 API에서 실제 결제 갱신일을 자동으로 가져오므로 직접 입력하지 않습니다.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text("현재 감지된 결제 갱신일: \(viewModel.openCodeAutoDetectedDate)")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.top, 1)
                    }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(6)
                
                // 2) Google AI Pro (API 비제공 - 사용자 직접 입력 필수)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))
                        .padding(.top, 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Google AI Pro")
                                .font(.system(size: 11, weight: .bold))
                            Text("사용자 직접 설정 필요")
                                .font(.system(size: 9.5, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.12))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                        
                        Text("구글 정책상 결제일 API를 제공하지 않으므로, 실제 카드 결제 일자를 직접 선택해 주세요.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("매월 결제일:")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $viewModel.googleBillingDay) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("매월 \(day)일").tag(day)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                    }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
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
            
            Divider()
            
            // Section 3: API 인증 (선택 사항)
            VStack(alignment: .leading, spacing: 8) {
                Text("서비스 인증 설정 (선택)")
                    .font(.system(size: 12, weight: .bold))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("OpenCode Go API Key (미입력 시 로컬 DB/CLI 자동 감지):")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    SecureField("sk-...", text: $viewModel.openCodeKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Google AI Studio API Key (미입력 시 Antigravity Keyring 자동 감지):")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    SecureField("AIza...", text: $viewModel.googleKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }
            }
            
            Spacer()
            
            // Bottom Action Bar
            HStack {
                if !viewModel.saveStatusMessage.isEmpty {
                    Text(viewModel.saveStatusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
                Spacer()
                
                Button("저장 및 즉시 갱신") {
                    settings.googleBillingDay = viewModel.googleBillingDay
                    settings.openCodeApiKey = viewModel.openCodeKeyInput
                    settings.googleApiKey = viewModel.googleKeyInput
                    viewModel.saveStatusMessage = "설정이 저장되었습니다."
                    
                    Task {
                        await usageManager.refreshAll()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        viewModel.saveStatusMessage = ""
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 450, height: 470)
    }
}
