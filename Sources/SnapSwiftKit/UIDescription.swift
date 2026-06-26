import Foundation

/// A normalized rectangle with the origin at the **top-left** corner
/// (x, y, width, height all in the 0...1 range relative to the image).
public struct NormalizedRect: Sendable, Codable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// A single piece of text detected in the screenshot, together with where it sits.
public struct DetectedTextElement: Sendable, Codable, Equatable {
    /// The recognized text.
    public var text: String
    /// Where the text sits within the image (top-left origin, normalized).
    public var frame: NormalizedRect
    /// Rough font size in points, estimated from the glyph height and image size.
    public var estimatedFontSize: Double
    /// Vision's confidence for this recognition, 0...1.
    public var confidence: Double

    public init(text: String, frame: NormalizedRect, estimatedFontSize: Double, confidence: Double) {
        self.text = text
        self.frame = frame
        self.estimatedFontSize = estimatedFontSize
        self.confidence = confidence
    }
}

/// A color sampled from the image, with how prevalent it is.
public struct ColorInfo: Sendable, Codable, Equatable {
    /// Hex string like `#RRGGBB`.
    public var hex: String
    /// Fraction of sampled pixels (0...1) that matched this color bucket.
    public var weight: Double

    public init(hex: String, weight: Double) {
        self.hex = hex
        self.weight = weight
    }
}

/// A structured, text-only description of a UI screenshot produced by `UIAnalyzer`.
///
/// This is the bridge between the **vision** stage (which understands pixels) and the
/// **generation** stage (a text-only LLM). Everything the model needs to reconstruct the
/// layout is captured here as plain, serializable data.
public struct UIDescription: Sendable, Codable, Equatable {
    /// Pixel dimensions of the source image.
    public var pixelWidth: Int
    public var pixelHeight: Int
    /// All recognized text, ordered top-to-bottom then left-to-right.
    public var textElements: [DetectedTextElement]
    /// Dominant colors across the whole image, most prevalent first.
    public var palette: [ColorInfo]
    /// Best guess at the overall background color.
    public var backgroundColorHex: String

    public init(
        pixelWidth: Int,
        pixelHeight: Int,
        textElements: [DetectedTextElement],
        palette: [ColorInfo],
        backgroundColorHex: String
    ) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.textElements = textElements
        self.palette = palette
        self.backgroundColorHex = backgroundColorHex
    }

    /// Aspect-ratio convenience (width / height).
    public var aspectRatio: Double {
        guard pixelHeight > 0 else { return 1 }
        return Double(pixelWidth) / Double(pixelHeight)
    }
}
