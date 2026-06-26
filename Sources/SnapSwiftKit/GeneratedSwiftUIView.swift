import Foundation
import FoundationModels

/// The structured result of code generation.
///
/// Using `@Generable` lets FoundationModels' **Guided Generation** force the model to return
/// exactly these fields — no stray prose, no markdown fences — so the `code` is copy-paste ready.
@Generable(description: "A complete, compilable SwiftUI view reconstructed from a UI screenshot.")
public struct GeneratedSwiftUIView: Sendable, Equatable {

    @Guide(description: "PascalCase name of the root SwiftUI View struct, e.g. \"LoginView\" or \"ProfileCardView\".")
    public var viewName: String

    @Guide(description: """
    The full Swift source code as a single string. It MUST contain: the `import SwiftUI` line, \
    the root View struct conforming to View, any small subviews it needs, and a `#Preview { ... }` block \
    at the end. Output raw Swift only — no markdown code fences, no commentary.
    """)
    public var code: String

    @Guide(description: "One short sentence describing what the screen is (e.g. \"A login form with email and password fields\").")
    public var summary: String
}
