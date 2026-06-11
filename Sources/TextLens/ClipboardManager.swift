import AppKit

enum ClipboardManager {
    /// Copy text to system clipboard and show a brief notification.
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Post notification for menu bar feedback
        NotificationCenter.default.post(
            name: .textLensCopied,
            object: nil,
            userInfo: ["preview": String(text.prefix(60))]
        )
    }
}

extension Notification.Name {
    static let textLensCopied = Notification.Name("com.textlens.copied")
}
