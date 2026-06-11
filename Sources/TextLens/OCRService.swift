import AppKit
import Vision
import Accelerate
import CoreImage

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
        guard let cgImage = decodeImage(from: imageData) else {
            throw OCRServiceError.imageDecodeFailed
        }

        // Upscale 5x first so all downstream processing has more pixels to work with
        let scaledCGImage = upscaleImage(cgImage, scale: 5) ?? cgImage

        // Then grayscale + sharpen on the high-res image
        let processedCGImage = preprocessForOCR(scaledCGImage)

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Disable language correction for accurate numeric/symbol preservation
        request.usesLanguageCorrection = false
        request.revision = VNRecognizeTextRequestRevision3
        // Apple Vision auto-detects the actual language from this priority list
        // Order matters: higher priority languages are preferred when ambiguous
        request.recognitionLanguages = ["th", "en", "ja", "zh-Hans", "zh-Hant", "ko", "vi"]
        // Common technical terms to improve mixed-language accuracy
        request.customWords = [
            "Vision", "Focus", "TextLens", "OCR", "macOS",
            "recognitionLanguages", "customWords", "LSUIElement",
            "Spotlight", "Settings", "System", "Privacy", "Security",
            "Screenshot", "Clipboard", "Shortcut", "Framework"
        ]

        let handler = VNImageRequestHandler(cgImage: processedCGImage, options: [:])
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

    /// Decode image data to CGImage via NSImage path (handles TIFF, PNG, etc.)
    private func decodeImage(from data: Data) -> CGImage? {
        guard let image = NSImage(data: data) else { return nil }
        return image.cgImage
    }

    /// Convert to grayscale + enhance contrast + sharpen for better OCR accuracy.
    /// Screen text uses sub-pixel anti-aliasing (color fringing) which confuses Vision.
    /// Grayscale removes color ambiguity; contrast boost + sharpen defines character edges.
    private func preprocessForOCR(_ image: CGImage) -> CGImage {
        let ciImage = CIImage(cgImage: image)
        let context = CIContext(options: [.workingColorSpace: NSNull()])

        // Step 1: Grayscale + contrast boost
        guard let grayFilter = CIFilter(name: "CIColorControls") else { return image }
        grayFilter.setValue(ciImage, forKey: kCIInputImageKey)
        grayFilter.setValue(0.0, forKey: kCIInputSaturationKey)
        grayFilter.setValue(2.0, forKey: kCIInputContrastKey)
        guard let contrastImage = grayFilter.outputImage else { return image }

        // Step 2: Sharpen to define character edges
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else { return image }
        sharpenFilter.setValue(contrastImage, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.4, forKey: kCIInputSharpnessKey)
        guard let sharpImage = sharpenFilter.outputImage else { return image }

        return context.createCGImage(sharpImage, from: sharpImage.extent) ?? image
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
