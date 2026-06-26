import Foundation

/// Builds the system instructions and the per-image prompt fed to the language model.
///
/// Kept separate so the CLI and GUI share the *exact* same prompting, and so the prompt
/// engineering can be iterated on in one place.
public enum PromptFactory {

    /// The persona + hard rules given to the model once per session.
    public static let instructions: String = """
    You are a senior frontend engineer and a world-class SwiftUI expert.

    Your job: given a STRUCTURED DESCRIPTION of a UI screenshot (recognized text with positions \
    and font sizes, plus a color palette), reconstruct it as clean, modern, idiomatic SwiftUI code.

    Hard rules:
    - Output Swift only. No markdown fences, no explanations, no commentary inside the code field.
    - Start with `import SwiftUI`.
    - Build the layout with native containers (VStack, HStack, ZStack, Grid, List, ScrollView) and \
      native views (Text, Button, Image(systemName:), TextField, Toggle, Divider, Spacer).
    - Reproduce the hierarchy, alignment, spacing, relative font sizes, and colors as faithfully as the \
      data allows. Larger detected font sizes → headings (.title/.headline/.largeTitle); smaller → \
      .body/.caption. Map weights sensibly.
    - Prefer semantic system colors (.primary, .secondary, Color(.systemBackground)) when a palette color \
      is close to black/white/gray. For distinct brand colors, use the `Color(hex:)` initializer.
    - If — and only if — you use `Color(hex:)`, append EXACTLY this extension at the very bottom of the file:

    extension Color {
        init(hex: String) {
            let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            var v: UInt64 = 0
            Scanner(string: s).scanHexInt64(&v)
            self.init(
                red: Double((v >> 16) & 0xFF) / 255,
                green: Double((v >> 8) & 0xFF) / 255,
                blue: Double(v & 0xFF) / 255
            )
        }
    }

    - Use SF Symbols (Image(systemName:)) as stand-ins for icons/glyphs you infer.
    - Replace any obviously dynamic content with sensible placeholder state (@State) so the file compiles \
      and previews on its own.
    - Always end the file with a `#Preview { RootViewName() }` block.
    - The code MUST compile as-is against the latest SwiftUI with no external dependencies.
    """

    /// Renders a ``UIDescription`` into the user-facing prompt text.
    public static func userPrompt(for description: UIDescription, hint: String? = nil) -> String {
        var lines: [String] = []
        lines.append("Reconstruct the following screen as a SwiftUI view.")
        lines.append("")
        lines.append("CANVAS")
        lines.append("- Image size: \(description.pixelWidth)×\(description.pixelHeight) px (aspect ratio \(String(format: "%.2f", description.aspectRatio))).")
        lines.append("- Background color: \(description.backgroundColorHex).")

        if !description.palette.isEmpty {
            let palette = description.palette
                .map { "\($0.hex) (\(Int(($0.weight * 100).rounded()))%)" }
                .joined(separator: ", ")
            lines.append("- Dominant colors: \(palette).")
        }

        lines.append("")
        lines.append("TEXT ELEMENTS (reading order; position is normalized 0–1, top-left origin)")
        if description.textElements.isEmpty {
            lines.append("- (No text was detected — infer a reasonable layout from the colors and aspect ratio.)")
        } else {
            for element in description.textElements {
                let f = element.frame
                let pos = positionLabel(for: f)
                lines.append(
                    "- \"\(element.text)\" — \(pos), x=\(round2(f.x)), y=\(round2(f.y)), w=\(round2(f.width)), h=\(round2(f.height)), ≈\(Int(element.estimatedFontSize))pt"
                )
            }
        }

        if let hint, !hint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("")
            lines.append("ADDITIONAL GUIDANCE FROM THE USER")
            lines.append(hint)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func round2(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// A human-friendly position like "top-center" / "middle-left".
    private static func positionLabel(for rect: NormalizedRect) -> String {
        let cx = rect.x + rect.width / 2
        let cy = rect.y + rect.height / 2
        let vertical = cy < 0.33 ? "top" : (cy < 0.66 ? "middle" : "bottom")
        let horizontal = cx < 0.33 ? "left" : (cx < 0.66 ? "center" : "right")
        return "\(vertical)-\(horizontal)"
    }
}
