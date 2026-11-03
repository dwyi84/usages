import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static weak var shared: AppDelegate?
    
    private var statusItem: NSStatusItem?
    private var popover = NSPopover()
    private let usageManager = UsageManager.shared
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory)
        
        setupMainMenu()
        setupPopover()
        setupStatusItem()
        
        usageManager.onSnapshotUpdated = { [weak self] in
            Task { @MainActor in
                self?.updateStatusIcon()
                if self?.popover.isShown == true {
                    self?.updatePopoverSize()
                }
            }
        }
        
        Task {
            await usageManager.refreshAll()
            UpdaterViewModel.shared.checkForUpdates() // CopyNinja 스타일 자동 업데이트 확인
        }
        
        // Refresh immediately when the Mac wakes up and when the local calendar
        // day changes. Without this the app could keep showing yesterday's
        // "today" buckets and stale reset countdowns after sleeping overnight.
        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.usageManager.refreshAll()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.usageManager.refreshAll()
            }
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
        popover.contentSize = NSSize(width: 480, height: 500)
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
                guard oc.isAvailable else { continue }
                let key = settings.selectedMetricKey(for: "opencode")
                let pct: Double
                let label: String
                let resetStr: String
                switch key {
                case "opencode_weekly":
                    pct = oc.openCodeWindows.weeklyRemainingPercent
                    label = L10n.isKorean ? "주간" : "Weekly"
                    resetStr = oc.openCodeWindows.weeklyResetString
                case "opencode_monthly":
                    pct = oc.openCodeWindows.monthlyRemainingPercent
                    label = L10n.isKorean ? "월간" : "Monthly"
                    resetStr = oc.openCodeWindows.monthlyResetString
                default: // "opencode_5h"
                    pct = oc.openCodeWindows.fiveHourRemainingPercent
                    label = L10n.isKorean ? "5시간" : "5h"
                    resetStr = oc.openCodeWindows.fiveHourResetString
                }
                let status: GaugeStatus = pct <= 15 ? .critical : (pct <= 35 ? .warning : .normal)
                gaugeItems.append(.init(percent: pct, status: status))
                tooltips.append("· OpenCode Go (\(label)): \(Int(pct))% \(L10n.remaining) (\(resetStr))")
                nearestBillingDays = min(nearestBillingDays, oc.daysUntilBilling)
                
            case "google_ai":
                let g = usageManager.googleAISnapshot
                guard g.isAvailable else { continue }
                let key = settings.selectedMetricKey(for: "google_ai")
                let pct: Double
                let label: String
                let resetStr: String
                switch key {
                case "google_claude_5h":
                    pct = g.googleGroups.claudeFiveHourRemainingPercent ?? g.googleGroups.overallRemainingPercent
                    label = L10n.isKorean ? "5시간(Claude&GPT)" : "5h (Claude&GPT)"
                    resetStr = g.googleGroups.claudeFiveHourResetString
                case "google_gemini_weekly":
                    pct = g.googleGroups.geminiWeeklyRemainingPercent ?? g.googleGroups.overallRemainingPercent
                    label = L10n.isKorean ? "주간(Gemini)" : "Weekly (Gemini)"
                    resetStr = g.googleGroups.geminiWeeklyResetString
                case "google_claude_weekly":
                    pct = g.googleGroups.claudeWeeklyRemainingPercent ?? g.googleGroups.overallRemainingPercent
                    label = L10n.isKorean ? "주간(Claude&GPT)" : "Weekly (Claude&GPT)"
                    resetStr = g.googleGroups.claudeWeeklyResetString
                case "google_argon_weekly":
                    pct = g.googleGroups.argonWeeklyRemainingPercent ?? g.googleGroups.overallRemainingPercent
                    label = L10n.isKorean ? "주간(Argon)" : "Weekly (Argon)"
                    resetStr = g.googleGroups.argonWeeklyResetString
                case "google_monthly":
                    pct = g.googleGroups.overallRemainingPercent > 0 ? g.googleGroups.overallRemainingPercent : g.remainingPercent
                    label = L10n.isKorean ? "월간" : "Monthly"
                    resetStr = g.googleGroups.nextBillingDateString.isEmpty ? "-" : g.googleGroups.nextBillingDateString
                default: // "google_gemini_5h"
                    pct = g.googleGroups.geminiFiveHourRemainingPercent ?? g.googleGroups.overallRemainingPercent
                    label = L10n.isKorean ? "5시간(Gemini)" : "5h (Gemini)"
                    resetStr = g.googleGroups.geminiFiveHourResetString
                }
                let status: GaugeStatus = pct <= 15 ? .critical : (pct <= 35 ? .warning : .normal)
                gaugeItems.append(.init(percent: pct, status: status))
                tooltips.append("· Google AI Pro (\(label)): \(Int(pct))% \(L10n.remaining) (\(resetStr))")
                // Only include Google's billing countdown when the user has
                // configured a reset day; otherwise daysUntilBilling is 0 and
                // would permanently show the "reset imminent" dot.
                if settings.googleBillingDayOfMonth > 0 {
                    nearestBillingDays = min(nearestBillingDays, g.daysUntilBilling)
                }
            case "openrouter":
                let or = usageManager.openRouterSnapshot
                guard or.isConnected else { continue }
                let bal = or.balanceUSD
                let pct = min(100.0, (bal / 10.0) * 100.0) // $10 기준 정규화
                gaugeItems.append(.init(percent: pct, status: or.status))
                tooltips.append("· OpenRouter: $\(String(format: "%.2f", bal))")
            default:
                break
            }
        }
        
        if gaugeItems.isEmpty {
            tooltips.append("· " + (L10n.isKorean ? "활성화된 AI 서비스 없음 (클릭하여 설정)" : "No active AI services (click to configure)"))
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
            updatePopoverSize()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    public func updatePopoverSize() {
        guard let view = popover.contentViewController?.view else { return }
        view.layoutSubtreeIfNeeded()
        let fitting = view.fittingSize
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        // 화면 해상도를 벗어나지 않도록 최대 높이를 550pt로 제한하고, 내부 스크롤로 처리
        let maxHeight = min(screenHeight - 120, 750)
        let targetHeight = fitting.height > 0 ? min(fitting.height, maxHeight) : min(500, maxHeight)
        popover.contentSize = NSSize(width: 480, height: targetHeight)
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
            UpdaterViewModel.shared.checkForUpdates() // CopyNinja 스타일 자동 업데이트 확인
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
