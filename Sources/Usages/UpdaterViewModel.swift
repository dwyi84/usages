import AppKit
import Foundation

struct ReleaseInfo {
    let version: String
    let htmlURL: URL
    let assetURL: URL?
}

@MainActor
public final class UpdaterViewModel: ObservableObject {
    public static let shared = UpdaterViewModel()

    public enum UpdateState: Equatable {
        case idle
        case checking
        case downloading
        case upToDate
        case updateAvailable
        case failed
    }

    public static let repoOwner = "dwyi84"
    public static let repoName = "usages"
    public static let currentVersion: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.1.0"
    }()

    @Published public private(set) var updateState: UpdateState = .idle
    @Published public var showUpdateConfirm = false

    private var pendingUpdate: ReleaseInfo?
    public var pendingUpdateVersion: String? { pendingUpdate?.version }

    private static let apiURL = URL(
        string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
    )!

    public var isBusy: Bool {
        updateState == .checking || updateState == .downloading
    }

    // MARK: Check

    public func checkForUpdates() {
        guard !isBusy else { return }
        updateState = .checking
        Task { [weak self] in
            guard let self else { return }
            if let release = await Self.fetchLatestRelease() {
                if Self.isNewer(release.version) {
                    self.pendingUpdate = release
                    self.updateState = .updateAvailable
                } else {
                    self.updateState = .upToDate
                    self.scheduleIdleReset()
                }
            } else {
                self.updateState = .failed
                self.scheduleIdleReset()
            }
        }
    }

    public func checkForUpdatesPresentingAlert() {
        guard !isBusy else { return }
        updateState = .checking
        Task { [weak self] in
            guard let self else { return }
            if let release = await Self.fetchLatestRelease() {
                if Self.isNewer(release.version) {
                    self.pendingUpdate = release
                    self.updateState = .updateAvailable
                    self.presentUpdateConfirmation()
                } else {
                    self.updateState = .upToDate
                    self.scheduleIdleReset()
                    Self.presentUpToDateAlert()
                }
            } else {
                self.updateState = .failed
                self.scheduleIdleReset()
                Self.presentFailedAlert()
            }
        }
    }

    public func presentUpdateConfirmation() {
        guard let release = pendingUpdate else { return }
        let alert = NSAlert()
        alert.messageText = L10n.isKorean
            ? "v\(release.version) 버전으로 업데이트하시겠습니까?"
            : "Update to v\(release.version)?"
        alert.informativeText = L10n.isKorean
            ? "AI Usages v\(release.version)을 사용할 수 있습니다 (현재 버전: v\(Self.currentVersion)). 자동으로 다운로드하여 설치한 후 앱이 재시작됩니다."
            : "AI Usages v\(release.version) is available. You're running v\(Self.currentVersion). It will be downloaded and installed automatically, then AI Usages will relaunch."
        alert.addButton(withTitle: L10n.updateNow)
        alert.addButton(withTitle: L10n.later)
        if alert.runModal() == .alertFirstButtonReturn {
            installNow()
        }
    }

    public func cancelPrompt() {
        showUpdateConfirm = false
        pendingUpdate = nil
        updateState = .idle
    }

    // MARK: Install

    public func installNow() {
        showUpdateConfirm = false
        guard let release = pendingUpdate, let assetURL = release.assetURL else {
            updateState = .failed
            scheduleIdleReset()
            return
        }
        updateState = .downloading
        Task { [weak self] in
            do {
                let zipURL = try await Self.downloadAsset(from: assetURL)
                Self.installAndRelaunch(zipURL: zipURL)
            } catch {
                guard let self else { return }
                self.updateState = .failed
                self.scheduleIdleReset()
            }
        }
    }

    private func scheduleIdleReset() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard let self else { return }
            if self.updateState == .upToDate || self.updateState == .failed {
                self.updateState = .idle
            }
        }
    }

    // MARK: GitHub Releases plumbing

    private static func fetchLatestRelease() async -> ReleaseInfo? {
        var request = URLRequest(url: apiURL)
        request.setValue("AIUsages/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let rawTag = json?["tag_name"] as? String,
                  let html = json?["html_url"] as? String,
                  let url = URL(string: html) else {
                return nil
            }
            let assetURL = (json?["assets"] as? [[String: Any]])?
                .compactMap { $0["browser_download_url"] as? String }
                .compactMap(URL.init(string:))
                .first { $0.pathExtension == "zip" }
            let tag = rawTag.hasPrefix("v") ? String(rawTag.dropFirst()) : rawTag
            return ReleaseInfo(version: tag, htmlURL: url, assetURL: assetURL)
        } catch {
            return nil
        }
    }

    private static func isNewer(_ version: String) -> Bool {
        let cleaned = version.hasPrefix("v") ? String(version.dropFirst()) : version
        return cleaned.compare(currentVersion, options: .numeric) == .orderedDescending
    }

    private static func downloadAsset(from url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.setValue("AIUsages/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 120
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("zip")
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    private static func installAndRelaunch(zipURL: URL) {
        let bundleURL = Bundle.main.bundleURL
        let appPath = bundleURL.path
        let appDir = bundleURL.deletingLastPathComponent().path
        let scriptPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("aiusages-update.sh")

        let script = """
        #!/bin/bash
        sleep 1
        pkill -x AIUsages 2>/dev/null || true
        sleep 0.5
        rm -rf "\(appPath)"
        ditto -x -k "\(zipURL.path)" "\(appDir)"
        chmod +x "\(appPath)/Contents/MacOS/AIUsages" 2>/dev/null || true
        xattr -dr com.apple.quarantine "\(appPath)" 2>/dev/null || true
        open "\(appPath)"
        rm -f "\(zipURL.path)" "\(scriptPath)"
        exit 0
        """

        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptPath
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]
        try? process.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Result alerts

    private static func presentUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.isKorean ? "최신 버전 사용 중" : "You're Up to Date"
        alert.informativeText = L10n.isKorean
            ? "AI Usages v\(currentVersion)은 최신 버전입니다."
            : "AI Usages v\(currentVersion) is the latest version."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func presentFailedAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.isKorean ? "업데이트 확인 실패" : "Update Check Failed"
        alert.informativeText = L10n.isKorean
            ? "GitHub Releases에 연결할 수 없습니다. 인터넷 연결을 확인해 주세요."
            : "Could not reach GitHub Releases. Check your connection and try again."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
