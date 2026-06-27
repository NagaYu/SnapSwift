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
        do {
            // Plain-text generation: the small on-device model produces complete code far more
            // reliably than when forced to pack a whole file into one Guided-Generation string field.
            let response = try await session.respond(to: prompt, options: makeOptions())
            let cleaned = Self.stripPlatformOnlyModifiers(in: Self.stripFences(response.content))
            let code = Self.ensureColorHexExtension(in: cleaned)
            return GeneratedSwiftUIView(
                viewName: Self.extractViewName(from: code) ?? "GeneratedView",
                code: code,
                summary: Self.summarize(description)
            )
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
                    let stream = session.streamResponse(to: prompt, options: makeOptions())
                    for try await snapshot in stream {
                        // Snapshots are cumulative plain text; strip fences defensively as they grow.
                        continuation.yield(Self.stripFences(snapshot.content))
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

    /// Low temperature for conservative code; a generous token budget so full files aren't truncated.
    private func makeOptions() -> GenerationOptions {
        GenerationOptions(temperature: temperature, maximumResponseTokens: 4000)
    }

    /// Pulls the root view name out of generated code, for display and file naming.
    static func extractViewName(from code: String) -> String? {
        for line in code.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("struct ") else { continue }
            let afterStruct = trimmed.dropFirst("struct ".count)
            let name = afterStruct.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            if afterStruct.contains("View"), !name.isEmpty {
                return String(name)
            }
        }
        return nil
    }

    /// A short, deterministic description derived from the layout (no extra model call).
    static func summarize(_ description: UIDescription) -> String {
        let count = description.textElements.count
        let firstText = description.textElements.first?.text
        if let firstText, !firstText.isEmpty {
            return "A \(description.pixelWidth)×\(description.pixelHeight) screen with \(count) text element(s), starting with “\(firstText)”."
        }
        return "A \(description.pixelWidth)×\(description.pixelHeight) screen with \(count) text element(s)."
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

    /// iOS-only view modifiers that don't exist on macOS. They are pure no-ops on a Mac, so any line
    /// consisting solely of such a modifier can be safely removed to keep the file compiling cross-platform.
    private static let iOSOnlyModifiers = [
        ".keyboardType(", ".autocapitalization(", ".textInputAutocapitalization(",
        ".navigationBarTitleDisplayMode(", ".navigationBarTitle(", ".listRowSeparatorTint(",
        ".statusBarHidden(", ".statusBar(",
    ]

    /// Deterministically drop standalone iOS-only modifier lines (e.g. `.keyboardType(.emailAddress)`).
    static func stripPlatformOnlyModifiers(in code: String) -> String {
        let kept = code.split(separator: "\n", omittingEmptySubsequences: false).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !iOSOnlyModifiers.contains { trimmed.hasPrefix($0) }
        }
        return kept.joined(separator: "\n")
    }

    /// Deterministic safety net: if the code uses `Color(hex:)` but never defines that initializer,
    /// append a Foundation-free `Color(hex:)` extension so the file always compiles.
    static func ensureColorHexExtension(in code: String) -> String {
        let usesHex = code.contains("Color(hex:")
        let definesHex = code.contains("init(hex")
        guard usesHex, !definesHex else { return code }
        let ext = """

        extension Color {
            init(hex: String) {
                var s = hex
                if s.hasPrefix("#") { s.removeFirst() }
                let v = UInt64(s, radix: 16) ?? 0
                self.init(
                    red: Double((v >> 16) & 0xFF) / 255,
                    green: Double((v >> 8) & 0xFF) / 255,
                    blue: Double(v & 0xFF) / 255
                )
            }
        }
        """
        return code + "\n" + ext + "\n"
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
