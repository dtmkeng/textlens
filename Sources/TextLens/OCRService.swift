import AppKit
import Vision
import Accelerate

final class OCRService {
    enum OCRServiceError: LocalizedError {
        case noTextFound
        case invalidImage
        case imageDecodeFailed

        var errorDescription: String? {
            switch self {
            case .noTextFound: return "No text found in the captured region"
            case .invalidImage: return "Invalid image for OCR processing"
            case .imageDecodeFailed: return "Failed to decode image data"
            }
        }
    }

    func recognizeText(from imageData: Data) async throws -> String {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage else {
            throw OCRServiceError.imageDecodeFailed
        }

        // Upscale 2x for better small-text recognition
        let scaledCGImage = upscaleImage(cgImage, scale: 2) ?? cgImage

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLanguages = ["th", "en"]
        // Common technical terms to improve mixed-language accuracy
        request.customWords = [
            "Vision", "Focus", "TextLens", "OCR", "macOS",
            "recognitionLanguages", "customWords", "LSUIElement",
            "Spotlight", "Settings", "System", "Privacy", "Security",
            "Screenshot", "Clipboard", "Shortcut", "Framework"
        ]

        let handler = VNImageRequestHandler(cgImage: scaledCGImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            throw OCRServiceError.noTextFound
        }

        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")

        guard !text.isEmpty else {
            throw OCRServiceError.noTextFound
        }

        return text
    }

    /// Upscale CGImage by a given scale factor using vImage (preserves sharpness)
    private func upscaleImage(_ image: CGImage, scale: Int) -> CGImage? {
        let width = image.width * scale
        let height = image.height * scale

        var format = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: nil,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent
        )

        var sourceBuffer = vImage_Buffer()
        defer { free(sourceBuffer.data) }

        guard vImageBuffer_InitWithCGImage(&sourceBuffer, &format, nil, image, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            return nil
        }

        var destBuffer = vImage_Buffer()
        guard vImageBuffer_Init(&destBuffer, UInt(height), UInt(width), 32, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            return nil
        }
        defer { free(destBuffer.data) }

        guard vImageScale_ARGB8888(&sourceBuffer, &destBuffer, nil, vImage_Flags(kvImageHighQualityResampling)) == kvImageNoError else {
            return nil
        }

        return try? destBuffer.createCGImage(format: format)
    }
}

// MARK: - Helpers

private extension NSImage {
    var cgImage: CGImage? {
        guard let data = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data) else { return nil }
        return bitmap.cgImage
    }
}
