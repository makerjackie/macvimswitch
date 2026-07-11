import Foundation
import AppKit

class UpdateManager {
    static let shared = UpdateManager()

    private let currentVersion: String
    private let githubRepo = "makerjackie/macvimswitch"
    private let updateRequestTimeout: TimeInterval = 15
    private var updateCheckTimer: Timer?

    private init() {
        // Read version from Info.plist
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            currentVersion = version
        } else {
            currentVersion = "0.0.0"
        }
    }

    // Start automatic update checking (every 24 hours)
    func startPeriodicCheck() {
        // Check immediately on startup
        checkForUpdates(silent: true)

        // Then check every 24 hours
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            self?.checkForUpdates(silent: true)
        }
    }

    func stopPeriodicCheck() {
        updateCheckTimer?.invalidate()
        updateCheckTimer = nil
    }

    // Manual check (triggered by user)
    func checkForUpdates(silent: Bool = false) {
        Task {
            do {
                if let latestVersion = try await fetchLatestVersion(), shouldCheckVersion(latestVersion) {
                    if isNewerVersion(latestVersion, than: currentVersion) {
                        await MainActor.run {
                            self.showUpdateAlert(newVersion: latestVersion)
                        }
                    } else if !silent {
                        await MainActor.run {
                            self.showNoUpdateAlert()
                        }
                    }
                }
            } catch {
                if !silent {
                    await MainActor.run {
                        self.showErrorAlert(error: error)
                    }
                }
            }
        }
    }

    private func fetchLatestVersion() async throws -> String? {
        // GitHub's public REST API is limited to 60 unauthenticated requests
        // per hour per IP. The stable releases/latest redirect is not subject
        // to that API quota and its final URL contains the latest tag.
        let url = URL(string: "https://github.com/\(githubRepo)/releases/latest")!
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = updateRequestTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("MacVimSwitch/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<400).contains(httpResponse.statusCode),
              let finalURL = httpResponse.url else {
            throw UpdateError.networkError
        }

        let components = finalURL.pathComponents
        guard let tagIndex = components.lastIndex(of: "tag"),
              components.indices.contains(tagIndex + 1) else {
            throw UpdateError.parseError
        }

        let tagName = components[tagIndex + 1]
        // Remove 'v' prefix if present
        return tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }

    private func isNewerVersion(_ newVersion: String, than currentVersion: String) -> Bool {
        let newComponents = newVersion.split(separator: ".").compactMap { Int($0) }
        let currentComponents = currentVersion.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(newComponents.count, currentComponents.count) {
            let new = i < newComponents.count ? newComponents[i] : 0
            let current = i < currentComponents.count ? currentComponents[i] : 0

            if new > current {
                return true
            } else if new < current {
                return false
            }
        }
        return false
    }

    private func showUpdateAlert(newVersion: String) {
        let alert = NSAlert()
        alert.messageText = "新版本可用"
        alert.informativeText = "MacVimSwitch \(newVersion) 已发布。当前版本: \(currentVersion)\n\n是否下载最新的 DMG 安装包?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "下载")
        alert.addButton(withTitle: "稍后提醒")
        alert.addButton(withTitle: "忽略此版本")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // This stable URL redirects to the DMG asset of the latest release.
            if let url = URL(string: "https://github.com/\(githubRepo)/releases/latest/download/MacVimSwitch.dmg") {
                NSWorkspace.shared.open(url)
            }
        } else if response == .alertThirdButtonReturn {
            // Save ignored version
            UserDefaults.standard.set(newVersion, forKey: "IgnoredVersion")
        }
    }

    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "已是最新版本"
        alert.informativeText = "您正在使用最新版本 \(currentVersion)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    private func showErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "检查更新失败"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    func shouldCheckVersion(_ version: String) -> Bool {
        // Don't check if this version is ignored
        if let ignoredVersion = UserDefaults.standard.string(forKey: "IgnoredVersion"),
           ignoredVersion == version {
            return false
        }
        return true
    }
}

enum UpdateError: LocalizedError {
    case networkError
    case parseError

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "无法连接到更新服务器"
        case .parseError:
            return "无法解析版本信息"
        }
    }
}
