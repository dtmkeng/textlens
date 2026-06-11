import AppKit
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager!
    private var overlayWindowController: OverlayWindowController!
    private let clipboardOCRService = ClipboardOCRService()
    private let ocrService = OCRService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable the app's main menu
        menuBarManager = MenuBarManager(
            startScreenCapture: { [weak self] in self?.startScreenCapture() },
            startClipboardOCR: { [weak self] in self?.startClipboardOCR() },
            quitAction: { NSApplication.shared.terminate(nil) }
        )

        overlayWindowController = OverlayWindowController()

        registerShortcuts()

        // Check Screen Recording permission at launch (non-blocking, just a heads-up)
        checkPermissionAtLaunch()
    }

    /// Show permission guidance on first launch without blocking the app.
    private func checkPermissionAtLaunch() {
        // Defer check to avoid showing dialog before menu bar is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !PermissionChecker.hasScreenRecordingPermission() {
                let alert = NSAlert()
                alert.messageText = "Screen Recording Permission Required"
                alert.informativeText = """
                TextLens needs Screen Recording permission to capture text from your screen.

                To grant access, open System Settings → Privacy & Security →
                Screen & System Audio Recording, and enable TextLens.

                You may need to restart TextLens after granting permission.
                """
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "OK")

                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    private func registerShortcuts() {
        KeyboardShortcuts.onKeyDown(for: .screenCapture) { [weak self] in
            self?.startScreenCapture()
        }

        KeyboardShortcuts.onKeyDown(for: .clipboardOCR) { [weak self] in
            self?.startClipboardOCR()
        }
    }

    private func startScreenCapture() {
        guard PermissionChecker.ensurePermission() else { return }

        // screencapture handles permission prompt natively
        overlayWindowController.beginCapture { [weak self] imageData in
            guard let self else { return }

            guard let imageData else {
                // screencapture was cancelled or permission denied
                self.showError(
                    "Screen capture cancelled or permission denied. "
                    + "Grant access in System Settings → Privacy & Security → "
                    + "Screen & System Audio Recording, then try again."
                )
                return
            }

            Task {
                do {
                    let text = try await self.ocrService.recognizeText(from: imageData)
                    await MainActor.run {
                        ClipboardManager.copy(text)
                    }
                } catch {
                    await MainActor.run {
                        self.showError(error.localizedDescription)
                    }
                }
            }
        }
    }

    private func startClipboardOCR() {
        Task {
            do {
                guard let text = try await clipboardOCRService.recognizeFromClipboard() else {
                    await MainActor.run {
                        self.showError("No image found in clipboard")
                    }
                    return
                }
                await MainActor.run {
                    ClipboardManager.copy(text)
                }
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    private func showError(_ message: String) {
        // Post a notification to show error in menu bar
        NotificationCenter.default.post(
            name: .textLensError,
            object: nil,
            userInfo: ["message": message]
        )
    }
}

extension Notification.Name {
    static let textLensError = Notification.Name("com.textlens.error")
}

extension KeyboardShortcuts.Name {
    static let screenCapture = Self("screenCapture", default: .init(.x, modifiers: [.control, .shift]))
    static let clipboardOCR = Self("clipboardOCR", default: .init(.c, modifiers: [.command, .shift]))
}
