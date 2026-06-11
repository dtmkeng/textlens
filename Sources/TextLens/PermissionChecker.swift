import AppKit

enum PermissionChecker {
    /// Check if Screen Recording permission has been granted.
    /// On macOS 13+, `CGWindowListCreateImage` returns nil without permission.
    static func hasScreenRecordingPermission() -> Bool {
        let image = CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            .optionOnScreenOnly,
            kCGNullWindowID,
            .nominalResolution
        )
        return image != nil
    }

    /// Show a guidance dialog if Screen Recording permission is missing.
    /// Returns `true` if permission is already granted, `false` otherwise.
    @discardableResult
    static func ensurePermission() -> Bool {
        guard !hasScreenRecordingPermission() else { return true }

        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = """
        TextLens needs Screen Recording permission to capture text from your screen.

        After clicking "Open Settings", enable TextLens in the list:
        System Settings → Privacy & Security → Screen & System Audio Recording

        You may need to restart TextLens after granting permission.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }

        return false
    }
}
