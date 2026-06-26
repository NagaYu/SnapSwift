import CoreGraphics
import Foundation

/// Turns raw pixels into a structured, text-only ``UIDescription``.
///
/// This abstraction is what lets SnapSwift stay future-proof: today it is backed by the
/// Vision framework (``VisionUIAnalyzer``), but the moment Apple ships a multimodal
/// FoundationModels endpoint, an alternative analyzer can be dropped in without touching
/// the rest of the pipeline.
public protocol UIAnalyzer: Sendable {
    func analyze(image: CGImage) async throws -> UIDescription
}

extension UIAnalyzer {
    /// Convenience: load an image from disk and analyze it.
    public func analyze(imageAt url: URL) async throws -> UIDescription {
        let image = try ImageLoader.load(at: url)
        return try await analyze(image: image)
    }
}
