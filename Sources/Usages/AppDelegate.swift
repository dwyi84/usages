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
        
        let oc = usageManager.openCodeSnapshot
        let g = usageManager.googleAISnapshot
        
        let nearestBillingDays = min(oc.daysUntilBilling, g.daysUntilBilling)
        
        let img = BatteryGaugeRenderer.renderUnifiedVerticalBars(
            openCodeRemainingPercent: oc.remainingPercent,
            openCodeStatus: oc.status,
            googleRemainingPercent: g.remainingPercent,
            googleStatus: g.status,
            daysUntilReset: nearestBillingDays
        )
        
        button.image = img
        button.toolTip = "AI Usages\n· OpenCode Go: \(Int(oc.remainingPercent))% 남음 (\(oc.openCodeWindows.monthlyResetString))\n· Google AI Pro: \(Int(g.remainingPercent))% 남음 (\(g.googleGroups.nextBillingDateString))\n클릭하여 상세 보기"
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
        menu.addItem(NSMenuItem(title: "AI Usages 새로고침", action: #selector(refreshClicked), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "AI Usages 종료", action: #selector(quitApp), keyEquivalent: "q"))
        
        sender.menu = menu
        sender.performClick(nil)
        sender.menu = nil
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
