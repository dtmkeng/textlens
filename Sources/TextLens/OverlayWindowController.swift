import AppKit

final class OverlayWindowController: NSObject {
    private var completionHandler: ((Data?) -> Void)?
    private var tempURL: URL?

    func beginCapture(completion: @escaping (Data?) -> Void) {
        self.completionHandler = completion

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "textlens_\(UUID().uuidString).png"
        let fileURL = tempDir.appendingPathComponent(fileName)
        self.tempURL = fileURL

        // Use macOS built-in screencapture CLI
        // -i: interactive (drag-to-select)
        // -r: retina resolution
        // No custom overlay needed, macOS handles permission
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", fileURL.path]

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    self.completionHandler?(nil)
                    self.cleanup()
                }
                return
            }

            let status = process.terminationStatus

            DispatchQueue.main.async {
                if status == 0, FileManager.default.fileExists(atPath: fileURL.path) {
                    let data = try? Data(contentsOf: fileURL)
                    try? FileManager.default.removeItem(at: fileURL)
                    self.completionHandler?(data)
                } else {
                    // User cancelled (Esc) or permission denied
                    try? FileManager.default.removeItem(at: fileURL)
                    self.completionHandler?(nil)
                }
                self.cleanup()
            }
        }
    }

    private func cleanup() {
        if let url = tempURL {
            try? FileManager.default.removeItem(at: url)
        }
        tempURL = nil
        completionHandler = nil
    }
}
