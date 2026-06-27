import ArgumentParser
import CoreGraphics
import Foundation
import SnapSwiftKit

@main
struct SnapSwiftCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "snapswift",
        abstract: "Turn a UI screenshot into clean SwiftUI code — 100% on-device.",
        discussion: """
        SnapSwift analyzes a screenshot with Apple's Vision framework and reconstructs it as
        SwiftUI using Apple's on-device FoundationModels language model. Nothing leaves your Mac.

        EXAMPLES:
          snapswift login.png
          snapswift login.png -o LoginView.swift
          snapswift dashboard.jpg --hint "use a dark theme" -o Dashboard.swift
        """,
        version: "0.1.0"
    )

    @Argument(help: "Path to the UI screenshot (.png, .jpg, .jpeg, .heic, .tiff).")
    var imagePath: String

    @Option(name: [.short, .long], help: "Write the generated SwiftUI to this file instead of the terminal.")
    var output: String?

    @Option(name: .long, help: "Extra guidance for the model, e.g. \"use a dark theme\".")
    var hint: String?

    @Flag(name: .long, help: "Disable ANSI colors in terminal output.")
    var noColor = false

    @Flag(name: [.short, .long], help: "Print analysis details to stderr.")
    var verbose = false

    @Flag(name: .long, help: "Only run the Vision analysis and print the detected layout as JSON (no model needed).")
    var analyzeOnly = false

    func run() async throws {
        let style = TerminalStyle(forced: noColor ? false : nil)
        let url = URL(fileURLWithPath: imagePath)
        let engine = SnapSwiftEngine()

        // 1. Load + analyze (the Vision stage needs no language model).
        let image: CGImage
        do {
            image = try ImageLoader.load(at: url)
        } catch {
            printError(error.localizedDescription, style: style)
            throw ExitCode.failure
        }

        printStatus(style.cyan("→ ") + SnapSwiftEngine.Stage.analyzingImage.label, style: style)
        let description: UIDescription
        do {
            description = try await engine.analyze(image: image)
        } catch {
            printError(error.localizedDescription, style: style)
            throw ExitCode.failure
        }

        if verbose {
            dumpDescription(description, style: style)
        }

        // 1a. Analyze-only → print the structured UIDescription and stop (works without Apple Intelligence).
        if analyzeOnly {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(description)
            print(String(decoding: data, as: UTF8.self))
            return
        }

        // 2. The generation stage needs the on-device model — make sure it can run.
        do {
            try engine.ensureAvailable()
        } catch {
            printError(error.localizedDescription, style: style)
            throw ExitCode.failure
        }

        // 3a. File output → one-shot structured generation (clean, fence-free).
        if let output {
            printStatus(style.cyan("→ ") + SnapSwiftEngine.Stage.generatingCode.label, style: style)
            do {
                let result = try await engine.generator.generate(from: description, hint: hint)
                let outURL = URL(fileURLWithPath: output)
                try ensureParentDirectory(for: outURL)
                let contents = result.code.hasSuffix("\n") ? result.code : result.code + "\n"
                try contents.write(to: outURL, atomically: true, encoding: .utf8)
                printStatus(style.green("✓ ") + "Wrote \(style.bold(result.viewName)) → \(output)", style: style)
                printStatus(style.gray("  " + result.summary), style: style)
            } catch {
                printError(error.localizedDescription, style: style)
                throw ExitCode.failure
            }
            return
        }

        // 3b. Terminal output → live streaming with syntax highlighting between dividers.
        let highlighter = SwiftSyntaxHighlighter(style: style)
        let width = 60
        let divider = String(repeating: "─", count: width)
        print(style.cyan(divider))
        print(style.bold(style.cyan("  SnapSwift · generated SwiftUI")))
        print(style.cyan(divider))

        var printedCount = 0
        var lineBuffer = ""
        do {
            for try await snapshot in engine.generator.streamCode(from: description, hint: hint) {
                // Snapshots are cumulative; print only the newly appended portion.
                guard snapshot.count >= printedCount else { continue }
                let delta = String(snapshot.dropFirst(printedCount))
                printedCount = snapshot.count
                lineBuffer += delta
                while let nl = lineBuffer.firstIndex(of: "\n") {
                    let line = String(lineBuffer[..<nl])
                    print(highlighter.highlight(line))
                    lineBuffer = String(lineBuffer[lineBuffer.index(after: nl)...])
                }
            }
            if !lineBuffer.isEmpty {
                print(highlighter.highlight(lineBuffer))
            }
        } catch {
            print("")
            printError(error.localizedDescription, style: style)
            throw ExitCode.failure
        }
        print(style.cyan(divider))
        printStatus(style.gray("Tip: pass -o <file.swift> to save directly to a file."), style: style)
    }

    // MARK: - Output helpers (status/errors go to stderr to keep stdout pipe-clean)

    private func printStatus(_ message: String, style: TerminalStyle) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    private func printError(_ message: String, style: TerminalStyle) {
        FileHandle.standardError.write(Data((style.red("✗ ") + message + "\n").utf8))
    }

    private func ensureParentDirectory(for url: URL) throws {
        let dir = url.deletingLastPathComponent()
        if !dir.path.isEmpty {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func dumpDescription(_ description: UIDescription, style: TerminalStyle) {
        var lines: [String] = []
        lines.append(style.gray("  image: \(description.pixelWidth)×\(description.pixelHeight)px, bg \(description.backgroundColorHex)"))
        lines.append(style.gray("  detected \(description.textElements.count) text element(s):"))
        for element in description.textElements.prefix(20) {
            lines.append(style.gray("    • \"\(element.text)\" ≈\(Int(element.estimatedFontSize))pt"))
        }
        FileHandle.standardError.write(Data((lines.joined(separator: "\n") + "\n").utf8))
    }
}
