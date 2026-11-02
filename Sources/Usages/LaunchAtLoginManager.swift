import Foundation
import ServiceManagement
import AppKit

@MainActor
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    @Published public var isEnabled: Bool = false {
        didSet {
            guard oldValue != isEnabled else { return }
            setLaunchAtLogin(enabled: isEnabled)
        }
    }
    
    private init() {
        self.isEnabled = checkLaunchAtLogin()
    }
    
    public func checkLaunchAtLogin() -> Bool {
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status == .enabled {
                return true
            }
        }
        
        let script = "tell application \"System Events\" to exists (login item \"AI Usages\")"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)
            if error == nil && result.booleanValue {
                return true
            }
        }
        return UserDefaults.standard.bool(forKey: "launchAtLogin")
    }
    
    public func setLaunchAtLogin(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
        
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                // Fallback to System Events
            }
        }
        
        let script: String
        if enabled {
            script = """
            tell application "System Events"
                if not (exists (login item "AI Usages")) then
                    make new login item at end with properties {path:"/Applications/AI Usages.app", hidden:false}
                end if
            end tell
            """
        } else {
            script = """
            tell application "System Events"
                delete (every login item whose name is "AI Usages")
            end tell
            """
        }
        
        DispatchQueue.global(qos: .utility).async {
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
        }
    }
}
