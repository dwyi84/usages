import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem?
    private var popover = NSPopover()
    private let usageManager = UsageManager.shared
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        setupMainMenu()
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
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
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
        
        for id in settings.providerOrder {
            guard settings.isProviderEnabled(id) else { continue }
            switch id {
            case "opencode":
                let oc = usageManager.openCodeSnapshot
                gaugeItems.append(.init(percent: oc.remainingPercent, status: oc.status))
                tooltips.append("· OpenCode Go: \(Int(oc.remainingPercent))% \(L10n.remaining) (\(oc.openCodeWindows.monthlyResetString))")
                nearestBillingDays = min(nearestBillingDays, oc.daysUntilBilling)
            case "google_ai":
                let g = usageManager.googleAISnapshot
                gaugeItems.append(.init(percent: g.remainingPercent, status: g.status))
                if !g.googleGroups.nextBillingDateString.isEmpty {
                    tooltips.append("· Google AI Pro: \(Int(g.remainingPercent))% \(L10n.remaining) (\(g.googleGroups.nextBillingDateString))")
                    nearestBillingDays = min(nearestBillingDays, g.daysUntilBilling)
                } else {
                    tooltips.append("· Google AI Pro: \(Int(g.remainingPercent))% \(L10n.remaining)")
                }
            case "openrouter":
                let or = usageManager.openRouterSnapshot
                let bal = or.balanceUSD
                let pct = min(100.0, (bal / 10.0) * 100.0) // $10 기준 정규화
                gaugeItems.append(.init(percent: pct, status: or.status))
                tooltips.append("· OpenRouter: $\(String(format: "%.2f", bal))")
            default:
                break
            }
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
            NSApp.activate(ignoringOtherApps: true)
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
