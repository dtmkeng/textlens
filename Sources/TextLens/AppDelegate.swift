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
