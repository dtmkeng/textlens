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
            process.arguments = ["-i", "-r", fileURL.path]

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

// MARK: - Overlay View

private final class OverlayView: NSView {
    var onCaptureComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private var isTracking = false
    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }

    func startTracking() {
        if let ta = trackingArea {
            removeTrackingArea(ta)
        }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(ta)
        trackingArea = ta
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        currentPoint = point
        isTracking = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isTracking else { return }
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isTracking, let start = startPoint, let current = currentPoint else { return }
        isTracking = false

        let selectionRect = normalizedRect(from: start, to: current)

        // Ignore tiny accidental clicks
        guard selectionRect.width > 5 && selectionRect.height > 5 else {
            onCancel?()
            return
        }

        onCaptureComplete?(selectionRect)
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let start = startPoint, let current = currentPoint, isTracking else {
            // Draw dimmed overlay
            NSColor.black.withAlphaComponent(0.3).setFill()
            dirtyRect.fill()
            return
        }

        // Dim entire screen
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()

        // Draw selection rectangle
        let selRect = normalizedRect(from: start, to: current)

        // Clear the selection area
        NSColor.clear.withAlphaComponent(0).setFill()
        selRect.fill(using: .clear)

        // Draw selection border
        NSColor.white.setStroke()
        let borderPath = NSBezierPath(rect: selRect)
        borderPath.lineWidth = 2
        borderPath.stroke()

        // Draw crosshair info
        let info = "\(Int(selRect.width)) × \(Int(selRect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.6)
        ]
        let attrStr = NSAttributedString(string: info, attributes: attrs)
        let infoSize = attrStr.size()
        let infoPoint = NSPoint(
            x: max(selRect.minX, selRect.minX + (selRect.width - infoSize.width) / 2),
            y: selRect.minY - infoSize.height - 8
        )
        // Ensure info text stays on screen
        let clampedPoint = NSPoint(
            x: max(4, min(infoPoint.x, bounds.width - infoSize.width - 4)),
            y: max(4, infoPoint.y)
        )
        attrStr.draw(at: clampedPoint)
    }

    private func normalizedRect(from p1: NSPoint, to p2: NSPoint) -> CGRect {
        CGRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )
    }
}
