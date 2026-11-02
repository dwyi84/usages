import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem?
    private var popover = NSPopover()
    private let usageManager = UsageManager.shared
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        setupPopover()
        setupStatusItem()
        
        usageManager.onSnapshotUpdated = { [weak self] in
            Task { @MainActor in
                self?.updateStatusIcon()
            }
        }
        
        Task {
            await usageManager.refreshAll()
        }
    }
    
    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: DetailPopoverView())
    }
    
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        self.statusItem = item
        updateStatusIcon()
    }
    
    public func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        
        var gaugeItems: [BatteryGaugeRenderer.GaugeItem] = []
        var tooltips: [String] = ["AI Usages"]
        var nearestBillingDays = 999
        
        let settings = AppSettings.shared
        
        if settings.isProviderEnabled("opencode") {
            let oc = usageManager.openCodeSnapshot
            gaugeItems.append(.init(percent: oc.remainingPercent, status: oc.status))
            tooltips.append("· OpenCode Go: \(Int(oc.remainingPercent))% \(L10n.remaining) (\(oc.openCodeWindows.monthlyResetString))")
            nearestBillingDays = min(nearestBillingDays, oc.daysUntilBilling)
        }
        
        if settings.isProviderEnabled("google_ai") {
            let g = usageManager.googleAISnapshot
            gaugeItems.append(.init(percent: g.remainingPercent, status: g.status))
            tooltips.append("· Google AI Pro: \(Int(g.remainingPercent))% \(L10n.remaining) (\(g.googleGroups.nextBillingDateString))")
            nearestBillingDays = min(nearestBillingDays, g.daysUntilBilling)
        }
        
        if settings.isProviderEnabled("openrouter") {
            let or = usageManager.openRouterSnapshot
            let bal = or.balanceUSD
            let pct = min(100.0, (bal / 10.0) * 100.0) // $10 기준 정규화
            gaugeItems.append(.init(percent: pct, status: or.status))
            tooltips.append("· OpenRouter: $\(String(format: "%.2f", bal))")
        }
        
        let img = BatteryGaugeRenderer.renderDynamicBars(
            items: gaugeItems,
            daysUntilReset: nearestBillingDays
        )
        
        button.image = img
        button.toolTip = tooltips.joined(separator: "\n")
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu(sender)
            return
        }
        togglePopover(sender)
    }
    
    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L10n.refreshApp, action: #selector(refreshClicked), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: L10n.checkForUpdates, action: #selector(checkUpdatesClicked), keyEquivalent: "u"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.quitApp, action: #selector(quitApp), keyEquivalent: "q"))
        
        sender.menu = menu
        sender.performClick(nil)
        sender.menu = nil
    }
    
    @objc private func checkUpdatesClicked() {
        UpdaterViewModel.shared.checkForUpdatesPresentingAlert()
    }
    
    @objc private func refreshClicked() {
        Task {
            await usageManager.refreshAll()
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
