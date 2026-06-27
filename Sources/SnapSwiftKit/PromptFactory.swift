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
    - COLORS — this is critical for the code to compile. Use ONLY these color forms:
        * SwiftUI semantic colors: .primary, .secondary, .accentColor
        * SwiftUI standard colors: .white, .black, .gray, .blue, .red, .green, .orange, .yellow, .pink, .purple
        * Custom colors via Color(red:green:blue:) (values 0...1), or Color(hex:) with the extension below.
      NEVER use UIKit/AppKit names — they do NOT exist on SwiftUI's Color and will fail to compile.
      Forbidden examples: Color.systemBackground, Color.systemBlue, Color.label, UIColor(...), NSColor(...).
      A hex color is ONLY ever written as Color(hex: "#F8F8F8"). NEVER write Color(.F8F8F8), Color(0xF8F8F8),
      or Color(.someHex) — those do not compile.
      For a screen background, use Color.white, or Color(hex: "#F8F8F8"), not Color.systemBackground.
    - Use `.ignoresSafeArea()` (not the deprecated `.edgesIgnoringSafeArea(.all)`).
    - If — and only if — you use `Color(hex:)`, append EXACTLY this extension at the very bottom of the file:

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

    - Use SF Symbols (Image(systemName:)) as stand-ins for icons/glyphs you infer.
    - STATE & BINDINGS — types must match or it won't compile:
        * Each TextField / SecureField binds to its OWN `@State private var x: String = ""`.
        * Toggle binds to a `@State private var x: Bool = false`. Never bind a TextField to a Bool.
        * A Button takes an action closure `{ }` and a label — it does not need a binding.
      Declare one correctly-typed @State property per interactive control and bind each to the right one.
    - CROSS-PLATFORM — the code must compile on macOS. Do NOT use iOS-only modifiers such as
      .keyboardType, .autocapitalization, .textInputAutocapitalization, or .navigationBarTitleDisplayMode.
      For a styled Button use `Button("Title") { }` (or `Button(role: .destructive) { } label: { Text("…") }`),
      never `Button(.destructive)`.
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
