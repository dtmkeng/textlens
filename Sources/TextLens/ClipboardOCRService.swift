import AppKit

final class ClipboardOCRService {
    private let ocrService = OCRService()

    /// OCR from clipboard image. Returns nil if clipboard contains no image.
    func recognizeFromClipboard() async throws -> String? {
        let imageData = await MainActor.run { clipboardImageData() }
        guard let imageData else { return nil }
        return try await ocrService.recognizeText(from: imageData)
    }

    @MainActor
    private func clipboardImageData() -> Data? {
        guard let pasteboardItem = NSPasteboard.general.pasteboardItems?.first else {
            return nil
        }

        // Try TIFF first (most common for copied images)
        if let tiffData = pasteboardItem.data(forType: .tiff) {
            return tiffData
        }

        // Try PNG
        if let pngData = pasteboardItem.data(forType: .png) {
            return pngData
        }

        // Fall back to NSImage conversion
        if let nsImage = NSImage(pasteboard: NSPasteboard.general) {
            return nsImage.tiffRepresentation
        }

        return nil
    }
}
