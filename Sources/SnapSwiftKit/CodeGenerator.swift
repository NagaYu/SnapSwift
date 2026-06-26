import Foundation

/// Generates SwiftUI code from a structured ``UIDescription``.
///
/// Backed today by ``FoundationModelsCodeGenerator``. Because both the analyzer and the generator
/// are protocols, a future multimodal backend (image-in / code-out) can replace this without
/// changing ``SnapSwiftEngine`` or any UI.
public protocol CodeGenerator: Sendable {
    /// Throws ``SnapSwiftError/modelUnavailable(reason:)`` if the model can't run right now.
    func ensureAvailable() throws

    /// Produce the final, structured result in one shot.
    func generate(from description: UIDescription, hint: String?) async throws -> GeneratedSwiftUIView

    /// Stream the code as it is generated. Each yielded value is the cumulative code so far.
    func streamCode(from description: UIDescription, hint: String?) -> AsyncThrowingStream<String, Error>
}
