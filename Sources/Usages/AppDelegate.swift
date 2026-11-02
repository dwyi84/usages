import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    
    // 단일 통합 Status Item
    private var statusItem: NSStatusItem?
    
    // Popover & Settings Window
    private var popover = NSPopover()
    private var settingsWindow: NSWindow?
    
    private let usageManager = UsageManager.shared
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock에 앱 아이콘을 띄우지 않고 툴바 전용 메뉴바 앱으로 동작
        NSApp.setActivationPolicy(.accessory)
        
        setupPopover()
        setupStatusItem()
        
        // 데이터 갱신 시 메뉴바 아이콘 업데이트 콜백 등록
        usageManager.onSnapshotUpdated = { [weak self] in
            Task { @MainActor in
                self?.updateStatusIcon()
            }
        }
        
        // 첫 번째 데이터 즉시 로드
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
        
        // 월간 사용률 및 가장 가까운 구독 결제일/만료일(D-day)
        let ocMonthly = oc.openCodeWindows.monthlyPercent > 0 ? oc.openCodeWindows.monthlyPercent : oc.usedPercent
        let gMonthly = g.googleCategories.monthlyPercent > 0 ? g.googleCategories.monthlyPercent : g.usedPercent
        let nearestBillingDays = min(oc.daysUntilBilling, g.daysUntilBilling)
        
        let img = BatteryGaugeRenderer.renderUnifiedVerticalBars(
            openCodeMonthlyPercent: ocMonthly,
            openCodeStatus: oc.status,
            googleMonthlyPercent: gMonthly,
            googleStatus: g.status,
            daysUntilReset: nearestBillingDays
        )
        
        let ocRemaining = max(0, Int(round(100.0 - ocMonthly)))
        let gRemaining = max(0, Int(round(100.0 - gMonthly)))
        
        button.image = img
        button.toolTip = "AI Usages\n· OpenCode Go 월간: \(ocRemaining)% 남음 [구독 갱신: \(oc.billingDateString) (D-\(oc.daysUntilBilling))]\n· Google AI Pro 월간: \(gRemaining)% 남음 [구독 갱신: \(g.billingDateString) (D-\(g.daysUntilBilling))]\n클릭하여 상세 보기"
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
        menu.addItem(NSMenuItem(title: "환경설정...", action: #selector(showPreferencesWindow(_:)), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Usages 종료", action: #selector(quitApp), keyEquivalent: "q"))
        
        sender.menu = menu
        sender.performClick(nil)
        sender.menu = nil
    }
    
    @objc private func refreshClicked() {
        Task {
            await usageManager.refreshAll()
        }
    }
    
    @objc public func showPreferencesWindow(_ sender: Any?) {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Usages 환경설정"
        window.contentViewController = NSHostingController(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        self.settingsWindow = window
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
