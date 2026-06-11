import AppKit
import SwiftUI

final class MenuBarManager: NSObject {
    private let statusItem: NSStatusItem
    private let startScreenCapture: () -> Void
    private let startClipboardOCR: () -> Void
    private let quitAction: () -> Void

    init(
        startScreenCapture: @escaping () -> Void,
        startClipboardOCR: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.startScreenCapture = startScreenCapture
        self.startClipboardOCR = startClipboardOCR
        self.quitAction = quitAction

        super.init()

        setupMenuBarIcon()
        setupMenu()
        observeErrors()
    }

    private func setupMenuBarIcon() {
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(
                pointSize: 16,
                weight: .regular
            )
            button.image = NSImage(
                systemSymbolName: "text.viewfinder",
                accessibilityDescription: "TextLens"
            )?.withSymbolConfiguration(config)
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        let captureItem = NSMenuItem(
            title: "Capture Screen…",
            action: #selector(captureScreen),
            keyEquivalent: ""
        )
        captureItem.target = self
        menu.addItem(captureItem)

        let clipboardItem = NSMenuItem(
            title: "OCR Clipboard",
            action: #selector(ocrClipboard),
            keyEquivalent: ""
        )
        clipboardItem.target = self
        menu.addItem(clipboardItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit TextLens",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func observeErrors() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showError(_:)),
            name: .textLensError,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didCopyText(_:)),
            name: .textLensCopied,
            object: nil
        )
    }

    @objc private func captureScreen() {
        startScreenCapture()
    }

    @objc private func ocrClipboard() {
        startClipboardOCR()
    }

    @objc private func openSettings() {
        let view = SettingsView()
        let controller = NSHostingController(rootView: view)
        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.show(relativeTo: statusItem.button!.bounds, of: statusItem.button!, preferredEdge: .maxY)
    }

    @objc private func quit() {
        quitAction()
    }

    @objc private func showError(_ notification: Notification) {
        guard let message = notification.userInfo?["message"] as? String else { return }
        statusItem.button?.contentTintColor = .systemRed

        let alert = NSAlert()
        alert.messageText = "TextLens"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()

        statusItem.button?.contentTintColor = nil
    }

    @objc private func didCopyText(_ notification: Notification) {
        guard let preview = notification.userInfo?["preview"] as? String else { return }
        flashFeedback(preview)
    }

    private func flashFeedback(_ preview: String) {
        guard let button = statusItem.button else { return }

        // Flash the icon blue briefly
        button.contentTintColor = .systemBlue

        // Show a brief tooltip-like notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            self.statusItem.button?.contentTintColor = nil
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
