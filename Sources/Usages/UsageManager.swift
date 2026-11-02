import Foundation
import SwiftUI
import Combine

@MainActor
public final class UsageManager: ObservableObject {
    public static let shared = UsageManager()
    
    @Published public var openCodeSnapshot = ServiceUsageSnapshot(service: .openCode)
    @Published public var googleAISnapshot = ServiceUsageSnapshot(service: .googleAI)
    @Published public var openRouterSnapshot = TokenCostSnapshot(providerId: "openrouter", providerName: "OpenRouter")
    
    @Published public var isRefreshing = false
    @Published public var lastRefreshedAt: Date = Date()
    @Published public var registeredProviders: [ProviderDescriptor] = []
    
    public var onSnapshotUpdated: (() -> Void)?
    
    private var timer: AnyCancellable?
    
    private init() {
        reloadProviders()
        startTimer()
    }
    
    public func reloadProviders() {
        let settings = AppSettings.shared
        
        let ocDetected = OpenCodeProvider.shared.isAvailable
        let gDetected = GoogleAIProvider.shared.isAvailable
        let orDetected = OpenRouterProvider.shared.isAvailable
        
        let all: [ProviderDescriptor] = [
            ProviderDescriptor(
                id: "opencode",
                name: "OpenCode Go",
                category: .quota,
                isDetected: ocDetected,
                isEnabled: settings.isProviderEnabled("opencode")
            ),
            ProviderDescriptor(
                id: "google_ai",
                name: "Google AI Pro",
                category: .quota,
                isDetected: gDetected,
                isEnabled: settings.isProviderEnabled("google_ai")
            ),
            ProviderDescriptor(
                id: "openrouter",
                name: "OpenRouter (API)",
                category: .tokenAndCost,
                isDetected: orDetected,
                isEnabled: settings.isProviderEnabled("openrouter")
            ),
            ProviderDescriptor(
                id: "claude",
                name: "Claude (Anthropic)",
                category: .quota,
                isDetected: false,
                isEnabled: settings.isProviderEnabled("claude")
            ),
            ProviderDescriptor(
                id: "cursor",
                name: "Cursor",
                category: .quota,
                isDetected: false,
                isEnabled: settings.isProviderEnabled("cursor")
            )
        ]
        
        // 1. 사용으로 체크된 프로바이더를 상위에 노출
        let enabledList = all.filter { $0.isEnabled }
        // 2. 나머지는 이어서 리스트업
        let disabledList = all.filter { !$0.isEnabled }
        
        self.registeredProviders = enabledList + disabledList
    }
    
    public func toggleProvider(id: String) {
        let isCurrentlyEnabled = AppSettings.shared.isProviderEnabled(id)
        AppSettings.shared.setProviderEnabled(id, enabled: !isCurrentlyEnabled)
        reloadProviders()
        self.onSnapshotUpdated?()
        
        Task {
            await refreshAll()
        }
    }
    
    public func startTimer() {
        timer?.cancel()
        let interval = AppSettings.shared.refreshIntervalSeconds
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.refreshAll()
                }
            }
    }
    
    public func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        let settings = AppSettings.shared
        
        async let oc = settings.isProviderEnabled("opencode")
            ? OpenCodeProvider.shared.fetchUsageSnapshot()
            : self.openCodeSnapshot
            
        async let g = settings.isProviderEnabled("google_ai")
            ? GoogleAIProvider.shared.fetchUsageSnapshot()
            : self.googleAISnapshot
            
        async let or = settings.isProviderEnabled("openrouter")
            ? OpenRouterProvider.shared.fetchSnapshot()
            : self.openRouterSnapshot
        
        let (ocResult, gResult, orResult) = await (oc, g, or)
        
        self.openCodeSnapshot = ocResult
        self.googleAISnapshot = gResult
        self.openRouterSnapshot = orResult
        self.lastRefreshedAt = Date()
        self.isRefreshing = false
        
        reloadProviders()
        self.onSnapshotUpdated?()
    }
}
