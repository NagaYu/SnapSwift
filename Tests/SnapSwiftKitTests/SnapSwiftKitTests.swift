import CoreGraphics
import Foundation
import Testing

@testable import SnapSwiftKit

@Suite("SnapSwiftKit core")
struct SnapSwiftKitTests {

    // MARK: - PromptFactory

    @Test("Instructions establish the SwiftUI-expert persona and ban markdown fences")
    func instructionsPersona() {
        let instructions = PromptFactory.instructions
        #expect(instructions.contains("SwiftUI expert"))
        #expect(instructions.contains("import SwiftUI"))
        #expect(instructions.contains("#Preview"))
        #expect(instructions.lowercased().contains("no markdown fences"))
    }

    @Test("User prompt embeds canvas size and detected text")
    func userPromptContents() {
        let description = UIDescription(
            pixelWidth: 390,
            pixelHeight: 844,
            textElements: [
                DetectedTextElement(
                    text: "Sign In",
                    frame: NormalizedRect(x: 0.1, y: 0.05, width: 0.3, height: 0.06),
                    estimatedFontSize: 34,
                    confidence: 0.99
                )
            ],
            palette: [ColorInfo(hex: "#0A84FF", weight: 0.4)],
            backgroundColorHex: "#FFFFFF"
        )
        let prompt = PromptFactory.userPrompt(for: description, hint: "use a dark theme")
        #expect(prompt.contains("390×844"))
        #expect(prompt.contains("Sign In"))
        #expect(prompt.contains("#0A84FF"))
        #expect(prompt.contains("use a dark theme"))
        #expect(prompt.contains("top-left")) // position label for the element
    }

    // MARK: - Fence stripping

    @Test("Markdown fences are stripped from model output")
    func stripFences() {
        let fenced = "```swift\nimport SwiftUI\nstruct V: View { var body: some View { Text(\"Hi\") } }\n```"
        let clean = FoundationModelsCodeGenerator.stripFences(fenced)
        #expect(clean.hasPrefix("import SwiftUI"))
        #expect(!clean.contains("```"))
    }

    @Test("Already-clean code is returned unchanged")
    func stripFencesNoop() {
        let code = "import SwiftUI\nstruct V: View { var body: some View { EmptyView() } }"
        #expect(FoundationModelsCodeGenerator.stripFences(code) == code)
    }

    // MARK: - Image loading

    @Test("Loading a missing file throws imageNotFound")
    func missingImageThrows() {
        let url = URL(fileURLWithPath: "/definitely/not/here_\(UUID().uuidString).png")
        #expect(throws: SnapSwiftError.self) {
            _ = try ImageLoader.load(at: url)
        }
    }

    // MARK: - Vision color sampling

    @Test("Vision analyzer reports dimensions and a plausible background color")
    func analyzeSolidColor() async throws {
        let image = Self.makeSolidImage(width: 120, height: 200, red: 1, green: 0, blue: 0)
        let analyzer = VisionUIAnalyzer()
        let description = try await analyzer.analyze(image: image)
        #expect(description.pixelWidth == 120)
        #expect(description.pixelHeight == 200)
        // Background should be dominated by red.
        #expect(description.backgroundColorHex.hasPrefix("#F")) // R channel near 0xF8
        #expect(!description.palette.isEmpty)
    }

    // MARK: - Codable round-trip

    @Test("UIDescription is Codable")
    func codableRoundTrip() throws {
        let original = UIDescription(
            pixelWidth: 10, pixelHeight: 20,
            textElements: [DetectedTextElement(text: "x", frame: .init(x: 0, y: 0, width: 1, height: 1), estimatedFontSize: 12, confidence: 1)],
            palette: [ColorInfo(hex: "#000000", weight: 1)],
            backgroundColorHex: "#000000"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UIDescription.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Helpers

    static func makeSolidImage(width: Int, height: Int, red: CGFloat, green: CGFloat, blue: CGFloat) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(red: red, green: green, blue: blue, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }
}
