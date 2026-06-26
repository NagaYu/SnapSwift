import CoreGraphics
import Foundation

/// The high-level entry point that ties the pipeline together:
/// **image → ``UIAnalyzer`` → ``UIDescription`` → ``CodeGenerator`` → ``GeneratedSwiftUIView``**.
///
/// Both the CLI and the desktop app use this exact type, so behavior stays identical across
/// interfaces. Swap the `analyzer` or `generator` in the initializer to change the backend.
public struct SnapSwiftEngine: Sendable {

    /// Coarse pipeline stages, suitable for driving a status label or progress bar.
    public enum Stage: Sendable, Equatable {
        case analyzingImage
        case generatingCode
        case completed

        /// A short, user-facing label (English).
        public var label: String {
            switch self {
            case .analyzingImage: return "Analyzing image…"
            case .generatingCode: return "Generating SwiftUI code…"
            case .completed: return "Done"
            }
        }

        /// Approximate fractional progress, for a determinate bar.
        public var fraction: Double {
            switch self {
            case .analyzingImage: return 0.33
            case .generatingCode: return 0.66
            case .completed: return 1.0
            }
        }
    }

    public let analyzer: UIAnalyzer
    public let generator: CodeGenerator

    public init(
        analyzer: UIAnalyzer = VisionUIAnalyzer(),
        generator: CodeGenerator = FoundationModelsCodeGenerator()
    ) {
        self.analyzer = analyzer
        self.generator = generator
    }

    /// Throws if the on-device model can't run right now.
    public func ensureAvailable() throws {
        try generator.ensureAvailable()
    }

    /// Just the analysis stage — useful for previews/debugging.
    public func analyze(image: CGImage) async throws -> UIDescription {
        try await analyzer.analyze(image: image)
    }

    // MARK: - One-shot generation

    /// Run the full pipeline on an in-memory image (used by the GUI).
    public func generate(
        image: CGImage,
        hint: String? = nil,
        onStage: (@Sendable (Stage) -> Void)? = nil
    ) async throws -> GeneratedSwiftUIView {
        onStage?(.analyzingImage)
        let description = try await analyzer.analyze(image: image)
        onStage?(.generatingCode)
        let result = try await generator.generate(from: description, hint: hint)
        onStage?(.completed)
        return result
    }

    /// Run the full pipeline on a file on disk (used by the CLI).
    public func generate(
        imageAt url: URL,
        hint: String? = nil,
        onStage: (@Sendable (Stage) -> Void)? = nil
    ) async throws -> GeneratedSwiftUIView {
        let image = try ImageLoader.load(at: url)
        return try await generate(image: image, hint: hint, onStage: onStage)
    }

    // MARK: - Streaming generation

    /// Stream the code (cumulative snapshots) for an in-memory image.
    public func streamCode(image: CGImage, hint: String? = nil) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let description = try await analyzer.analyze(image: image)
                    for try await snapshot in generator.streamCode(from: description, hint: hint) {
                        continuation.yield(snapshot)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Stream the code (cumulative snapshots) for a file on disk.
    public func streamCode(imageAt url: URL, hint: String? = nil) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let image = try ImageLoader.load(at: url)
                    for try await snapshot in streamCode(image: image, hint: hint) {
                        continuation.yield(snapshot)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
