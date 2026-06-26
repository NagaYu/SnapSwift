import CoreGraphics
import Foundation
import Vision

/// The default ``UIAnalyzer``, powered entirely by Apple's on-device **Vision** framework.
///
/// It performs two passes over the screenshot, both 100% local:
/// 1. **Text recognition** — every label, button title, and caption, with its position and an
///    estimated font size.
/// 2. **Color sampling** — a small dominant-color palette plus a best-guess background color.
public struct VisionUIAnalyzer: UIAnalyzer {

    /// Minimum confidence below which a recognized string is discarded as noise.
    public var minimumTextConfidence: Float

    public init(minimumTextConfidence: Float = 0.3) {
        self.minimumTextConfidence = minimumTextConfidence
    }

    public func analyze(image: CGImage) async throws -> UIDescription {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            throw SnapSwiftError.analysisFailed(underlying: "Image has zero dimensions.")
        }

        let textElements = try recognizeText(in: image, pixelHeight: height)
        let (palette, background) = samplePalette(of: image)

        return UIDescription(
            pixelWidth: width,
            pixelHeight: height,
            textElements: textElements,
            palette: palette,
            backgroundColorHex: background
        )
    }

    // MARK: - Text

    private func recognizeText(in image: CGImage, pixelHeight: Int) throws -> [DetectedTextElement] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw SnapSwiftError.analysisFailed(underlying: error.localizedDescription)
        }

        let observations = (request.results ?? [])
        var elements: [DetectedTextElement] = []
        for observation in observations {
            guard
                let candidate = observation.topCandidates(1).first,
                observation.confidence >= minimumTextConfidence,
                !candidate.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }

            // Vision's bounding box is normalized with a bottom-left origin; flip Y for top-left.
            let bb = observation.boundingBox
            let frame = NormalizedRect(
                x: Double(bb.minX),
                y: Double(1.0 - bb.maxY),
                width: Double(bb.width),
                height: Double(bb.height)
            )
            let estimatedFontSize = (frame.height * Double(pixelHeight)).rounded()

            elements.append(
                DetectedTextElement(
                    text: candidate.string,
                    frame: frame,
                    estimatedFontSize: estimatedFontSize,
                    confidence: Double(observation.confidence)
                )
            )
        }

        // Reading order: top-to-bottom, then left-to-right (with a small row tolerance).
        elements.sort { lhs, rhs in
            if abs(lhs.frame.y - rhs.frame.y) > 0.02 {
                return lhs.frame.y < rhs.frame.y
            }
            return lhs.frame.x < rhs.frame.x
        }
        return elements
    }

    // MARK: - Color

    /// Downscale to a small grid and bucket colors to find the dominant palette.
    private func samplePalette(of image: CGImage) -> (palette: [ColorInfo], background: String) {
        let sampleSize = 64
        let bytesPerPixel = 4
        let bytesPerRow = sampleSize * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: sampleSize * sampleSize * bytesPerPixel)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctx = pixels.withUnsafeMutableBytes({ ptr -> CGContext? in
            CGContext(
                data: ptr.baseAddress,
                width: sampleSize,
                height: sampleSize,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }) else {
            return ([], "#FFFFFF")
        }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        var buckets: [UInt32: Int] = [:]
        let total = sampleSize * sampleSize
        for i in 0..<total {
            let o = i * bytesPerPixel
            // Quantize each channel to 5 bits (32-level) buckets to merge near-identical colors.
            let r = pixels[o] & 0xF8
            let g = pixels[o + 1] & 0xF8
            let b = pixels[o + 2] & 0xF8
            let key = (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)
            buckets[key, default: 0] += 1
        }

        let sorted = buckets.sorted { $0.value > $1.value }
        let palette: [ColorInfo] = sorted.prefix(6).map { entry in
            ColorInfo(hex: Self.hex(from: entry.key), weight: Double(entry.value) / Double(total))
        }
        let background = sorted.first.map { Self.hex(from: $0.key) } ?? "#FFFFFF"
        return (palette, background)
    }

    private static func hex(from key: UInt32) -> String {
        let r = (key >> 16) & 0xFF
        let g = (key >> 8) & 0xFF
        let b = key & 0xFF
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
