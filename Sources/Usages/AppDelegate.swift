import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    
    // Status Items
    private var openCodeStatusItem: NSStatusItem?
    private var googleStatusItem: NSStatusItem?
    private var combinedStatusItem: NSStatusItem?
    
    // Popover
    private var popover = NSPopover()
    private var settingsWindow: NSWindow?
    
    private let usageManager = UsageManager.shared
    private let settings = AppSettings.shared
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock에 앱 아이콘을 띄우지 않고 툴바 전용 메뉴바 앱으로 동작
        NSApp.setActivationPolicy(.accessory)
        
        setupPopover()
        setupStatusItems()
        
        // 데이터 갱신 시 메뉴바 아이콘 업데이트 콜백 등록
        usageManager.onSnapshotUpdated = { [weak self] in
            Task { @MainActor in
                self?.updateStatusItemIcons()
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
    
    public func setupStatusItems() {
        // 기존 아이콘 제거
        if let oc = openCodeStatusItem {
            NSStatusBar.system.removeStatusItem(oc)
            openCodeStatusItem = nil
        }
        if let g = googleStatusItem {
            NSStatusBar.system.removeStatusItem(g)
            googleStatusItem = nil
        }
        if let comb = combinedStatusItem {
            NSStatusBar.system.removeStatusItem(comb)
            combinedStatusItem = nil
        }
        
        if settings.displayMode == .separateItems {
            // 2개 개별 아이콘 모드
            let ocItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = ocItem.button {
                button.target = self
                button.action = #selector(statusItemClicked(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
            openCodeStatusItem = ocItem
            
            let gItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = gItem.button {
                button.target = self
                button.action = #selector(statusItemClicked(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
            googleStatusItem = gItem
        } else {
            // 통합 단일 아이콘 모드
            let combItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = combItem.button {
                button.target = self
                button.action = #selector(statusItemClicked(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
            combinedStatusItem = combItem
        }
        
        updateStatusItemIcons()
    }
    
    public func updateStatusItemIcons() {
        let oc = usageManager.openCodeSnapshot
        let g = usageManager.googleAISnapshot
        
        if settings.displayMode == .separateItems {
            // OpenCode Item
            if let ocBtn = openCodeStatusItem?.button {
                let img = BatteryGaugeRenderer.renderBatteryItem(
                    label: settings.showShortLabel ? "OC" : nil,
                    percent: oc.usedPercent,
                    showPercent: settings.showPercentText,
                    status: oc.status
                )
                ocBtn.image = img
                ocBtn.toolTip = "OpenCode Go: \(Int(oc.usedPercent))% 소모 (\(oc.resetTimeString))\n클릭하여 상세 보기"
            }
            
            // Google AI Item
            if let gBtn = googleStatusItem?.button {
                let img = BatteryGaugeRenderer.renderBatteryItem(
                    label: settings.showShortLabel ? "G" : nil,
                    percent: g.usedPercent,
                    showPercent: settings.showPercentText,
                    status: g.status
                )
                gBtn.image = img
                gBtn.toolTip = "Google AI Pro: \(Int(g.usedPercent))% 소모 (\(g.resetTimeString))\n클릭하여 상세 보기"
            }
        } else {
            // Combined Item
            if let combBtn = combinedStatusItem?.button {
                let img = BatteryGaugeRenderer.renderCombinedItem(
                    openCodePercent: oc.usedPercent,
                    openCodeStatus: oc.status,
                    googlePercent: g.usedPercent,
                    googleStatus: g.status,
                    showPercent: settings.showPercentText
                )
                combBtn.image = img
                combBtn.toolTip = "AI Usages (OpenCode & Google AI Pro)\n클릭하여 상세 보기"
            }
        }
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            // 우클릭 시 컨텍스트 메뉴 표시
            showContextMenu(sender)
            return
        }
        
        // 좌클릭 시 팝오버 토글
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
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 490),
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
