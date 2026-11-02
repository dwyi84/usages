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
        
        let all: [ProviderDescriptor] = [
            ProviderDescriptor(
                id: "codex",
                name: "Codex",
                category: .tokenAndCost,
                isDetected: ProviderDetector.isDetected(id: "codex"),
                isEnabled: settings.isProviderEnabled("codex")
            ),
            ProviderDescriptor(
                id: "claude",
                name: "Claude",
                category: .quota,
                isDetected: ProviderDetector.isDetected(id: "claude"),
                isEnabled: settings.isProviderEnabled("claude")
            ),
            ProviderDescriptor(
                id: "cursor",
                name: "Cursor",
                category: .quota,
                isDetected: ProviderDetector.isDetected(id: "cursor"),
                isEnabled: settings.isProviderEnabled("cursor")
            ),
            ProviderDescriptor(
                id: "google_ai",
                name: "Google AI",
                category: .quota,
                isDetected: ProviderDetector.isDetected(id: "google_ai"),
                isEnabled: settings.isProviderEnabled("google_ai")
            ),
            ProviderDescriptor(
                id: "opencode",
                name: "OpenCode Go",
                category: .quota,
                isDetected: ProviderDetector.isDetected(id: "opencode"),
                isEnabled: settings.isProviderEnabled("opencode")
            ),
            ProviderDescriptor(
                id: "openrouter",
                name: "OpenRouter",
                category: .tokenAndCost,
                isDetected: ProviderDetector.isDetected(id: "openrouter"),
                isEnabled: settings.isProviderEnabled("openrouter")
            ),
            ProviderDescriptor(
                id: "copilot",
                name: "Copilot",
                category: .quota,
                isDetected: ProviderDetector.isDetected(id: "copilot"),
                isEnabled: settings.isProviderEnabled("copilot")
            ),
            ProviderDescriptor(
                id: "perplexity",
                name: "Perplexity",
                category: .tokenAndCost,
                isDetected: ProviderDetector.isDetected(id: "perplexity"),
                isEnabled: settings.isProviderEnabled("perplexity")
            ),
            ProviderDescriptor(
                id: "deepseek",
                name: "DeepSeek",
                category: .tokenAndCost,
                isDetected: ProviderDetector.isDetected(id: "deepseek"),
                isEnabled: settings.isProviderEnabled("deepseek")
            )
        ]
        
        self.registeredProviders = all
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
