import Foundation

/// Errors surfaced by the SnapSwift core engine.
public enum SnapSwiftError: Error, LocalizedError, Sendable {
    /// The provided image file could not be found.
    case imageNotFound(path: String)
    /// The image file could not be decoded into a usable bitmap.
    case imageDecodingFailed(path: String)
    /// The on-device language model is unavailable (with a human-readable reason).
    case modelUnavailable(reason: String)
    /// The Vision analysis step failed.
    case analysisFailed(underlying: String)
    /// The language model failed while generating code.
    case generationFailed(underlying: String)

    public var errorDescription: String? {
        switch self {
        case .imageNotFound(let path):
            return "Image not found at path: \(path)"
        case .imageDecodingFailed(let path):
            return "Could not decode the image at: \(path). Supported formats: PNG, JPEG, HEIC, TIFF."
        case .modelUnavailable(let reason):
            return "Apple's on-device model is unavailable. \(reason)"
        case .analysisFailed(let underlying):
            return "Image analysis failed: \(underlying)"
        case .generationFailed(let underlying):
            return "SwiftUI code generation failed: \(underlying)"
        }
    }
}
