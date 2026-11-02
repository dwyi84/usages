import SwiftUI

public final class SettingsViewModel: ObservableObject {
    @Published public var openCodeKeyInput: String
    @Published public var googleKeyInput: String
    @Published public var saveStatusMessage: String = ""
    
    public init() {
        self.openCodeKeyInput = AppSettings.shared.openCodeApiKey
        self.googleKeyInput = AppSettings.shared.googleApiKey
    }
}

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var usageManager = UsageManager.shared
    @ObservedObject var viewModel: SettingsViewModel
    
    public init(viewModel: SettingsViewModel = SettingsViewModel()) {
        self.viewModel = viewModel
    }
    
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
            
            // Section 1: 갱신 주기
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
            
            // Section 2: API 인증 (선택 사항)
            VStack(alignment: .leading, spacing: 10) {
                Text("서비스 인증 설정 (선택)")
                    .font(.system(size: 12, weight: .bold))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("OpenCode Go API Key (미입력 시 로컬 DB/CLI 자동 감지):")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                    SecureField("sk-...", text: $viewModel.openCodeKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Google AI Studio API Key (미입력 시 Antigravity Keyring 자동 감지):")
                        .font(.system(size: 10.5))
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
        .frame(width: 420, height: 320)
    }
}
