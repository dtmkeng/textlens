import AppKit

final class UpdateChecker {
    private let currentVersion: String
    private let repoOwner = "dtmkeng"
    private let repoName = "textlens"

    init() {
        self.currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// Check GitHub Releases for a newer version.
    /// Shows a dialog: "New version available" or "You're up to date".
    func checkForUpdates() {
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            showError("Could not create update URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error = error {
                    self.showError("Update check failed: \(error.localizedDescription)")
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    self.showError("Could not parse update response")
                    return
                }

                let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

                if latestVersion.compare(self.currentVersion, options: .numeric) == .orderedDescending {
                    self.showUpdateAvailable(latestVersion: latestVersion, releaseData: json)
                } else {
                    self.showUpToDate()
                }
            }
        }
        task.resume()
    }

    private func showUpToDate() {
        let alert = NSAlert()
        alert.messageText = "TextLens is up to date"
        alert.informativeText = "Version \(currentVersion) is the latest available."
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func showUpdateAvailable(latestVersion: String, releaseData: [String: Any]) {
        let releaseURL = releaseData["html_url"] as? String ?? "https://github.com/\(repoOwner)/\(repoName)/releases"
        let body = (releaseData["body"] as? String)?
            .components(separatedBy: "\n").prefix(5).joined(separator: "\n") ?? ""

        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "Version \(latestVersion) is now available (you have \(currentVersion)).\n\n\(body)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: releaseURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
