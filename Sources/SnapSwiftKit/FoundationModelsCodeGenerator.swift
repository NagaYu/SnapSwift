import Foundation
import FoundationModels

/// A ``CodeGenerator`` powered by Apple's on-device **FoundationModels** language model.
///
/// Everything runs locally — nothing about the user's screenshot ever leaves the device.
/// Guided Generation (`@Generable`) is used so the model returns clean, fenced-free Swift.
public struct FoundationModelsCodeGenerator: CodeGenerator {

    /// Sampling temperature. Low values keep code deterministic and conservative.
    public var temperature: Double

    public init(temperature: Double = 0.2) {
        self.temperature = temperature
    }

    public func ensureAvailable() throws {
        switch SystemLanguageModel.default.availability {
        case .available:
            return
        case .unavailable(let reason):
            throw SnapSwiftError.modelUnavailable(reason: Self.describe(reason))
        }
    }

    public func generate(from description: UIDescription, hint: String?) async throws -> GeneratedSwiftUIView {
        try ensureAvailable()
        let session = makeSession()
        let prompt = PromptFactory.userPrompt(for: description, hint: hint)
        let options = GenerationOptions(temperature: temperature)
        do {
            let response = try await session.respond(
                to: prompt,
                generating: GeneratedSwiftUIView.self,
                options: options
            )
            return sanitize(response.content)
        } catch {
            throw SnapSwiftError.generationFailed(underlying: error.localizedDescription)
        }
    }

    public func streamCode(from description: UIDescription, hint: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try ensureAvailable()
                    let session = makeSession()
                    let prompt = PromptFactory.userPrompt(for: description, hint: hint)
                    let options = GenerationOptions(temperature: temperature)
                    let stream = session.streamResponse(
                        to: prompt,
                        generating: GeneratedSwiftUIView.self,
                        options: options
                    )
                    for try await snapshot in stream {
                        if let code = snapshot.content.code {
                            continuation.yield(code)
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: SnapSwiftError.generationFailed(underlying: error.localizedDescription)
                    )
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Private

    private func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: PromptFactory.instructions)
    }

    /// Defensive cleanup in case the model still wraps code in markdown fences.
    private func sanitize(_ view: GeneratedSwiftUIView) -> GeneratedSwiftUIView {
        var view = view
        view.code = Self.stripFences(view.code)
        return view
    }

    static func stripFences(_ code: String) -> String {
        var text = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            // Drop the opening fence line (``` or ```swift) and the trailing fence.
            if let firstNewline = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: firstNewline)...])
            }
            if let range = text.range(of: "```", options: .backwards) {
                text = String(text[..<range.lowerBound])
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device is not eligible for Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled. Turn it on in System Settings → Apple Intelligence & Siri."
        case .modelNotReady:
            return "The on-device model is still downloading or warming up. Please try again in a moment."
        @unknown default:
            return "The model is unavailable for an unknown reason."
        }
    }
}
