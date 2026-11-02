import Foundation
import SwiftUI
import Combine

@MainActor
public final class UsageManager: ObservableObject {
    public static let shared = UsageManager()
    
    @Published public var openCodeSnapshot = ServiceUsageSnapshot(service: .openCode)
    @Published public var googleAISnapshot = ServiceUsageSnapshot(service: .googleAI)
    @Published public var isRefreshing = false
    @Published public var lastRefreshedAt: Date = Date()
    
    public var onSnapshotUpdated: (() -> Void)?
    
    private var timer: AnyCancellable?
    
    private init() {
        startTimer()
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
        
        async let oc = OpenCodeProvider.shared.fetchUsageSnapshot()
        async let g = GoogleAIProvider.shared.fetchUsageSnapshot()
        
        let (ocResult, gResult) = await (oc, g)
        
        self.openCodeSnapshot = ocResult
        self.googleAISnapshot = gResult
        self.lastRefreshedAt = Date()
        self.isRefreshing = false
        
        self.onSnapshotUpdated?()
    }
}
