import AppKit
import Foundation
import Observation
import SnapSwiftKit
import SwiftUI

/// Drives the desktop app. All the heavy lifting is delegated to ``SnapSwiftEngine`` from
/// the shared `SnapSwiftKit` module — the exact same core the CLI uses.
@MainActor
@Observable
final class AppViewModel {

    // Inputs
    var image: NSImage?
    var hint: String = ""

    // Outputs
    var generatedCode: String = ""
    var viewName: String = ""

    // Status
    var stage: SnapSwiftEngine.Stage?
    var statusMessage: String = "Drop a UI screenshot on the left to begin."
    var isWorking: Bool = false
    var errorMessage: String?

    private let engine = SnapSwiftEngine()
    private var task: Task<Void, Never>?

    var canGenerate: Bool { image != nil && !isWorking }
    var hasResult: Bool { !generatedCode.isEmpty }
    var progress: Double {
        guard isWorking || stage == .completed else { return 0 }
        return stage?.fraction ?? 0
    }

    // MARK: - Loading images

    func setImage(_ image: NSImage) {
        self.image = image
        generatedCode = ""
        viewName = ""
        errorMessage = nil
        stage = nil
        statusMessage = "Ready. Press “Generate SwiftUI”."
    }

    func loadImage(at url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            errorMessage = "Could not load image at \(url.lastPathComponent)."
            return
        }
        setImage(image)
    }

    func openImagePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            loadImage(at: url)
        }
    }

    // MARK: - Generation

    func generate() {
        guard let image, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            errorMessage = "The dropped image could not be read."
            return
        }

        task?.cancel()
        isWorking = true
        errorMessage = nil
        generatedCode = ""
        viewName = ""
        stage = .analyzingImage
        statusMessage = SnapSwiftEngine.Stage.analyzingImage.label

        let trimmedHint = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        let hintValue = trimmedHint.isEmpty ? nil : trimmedHint

        task = Task { [engine] in
            do {
                try engine.ensureAvailable()
                var sawFirstSnapshot = false
                for try await snapshot in engine.streamCode(image: cgImage, hint: hintValue) {
                    if !sawFirstSnapshot {
                        sawFirstSnapshot = true
                        self.stage = .generatingCode
                        self.statusMessage = SnapSwiftEngine.Stage.generatingCode.label
                    }
                    self.generatedCode = snapshot
                    self.viewName = Self.extractViewName(from: snapshot) ?? self.viewName
                }
                self.stage = .completed
                self.statusMessage = "Done — \(self.viewName.isEmpty ? "view" : self.viewName) generated."
            } catch is CancellationError {
                self.statusMessage = "Cancelled."
            } catch {
                self.errorMessage = error.localizedDescription
                self.statusMessage = "Failed."
            }
            self.isWorking = false
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isWorking = false
        statusMessage = "Cancelled."
    }

    func copyCodeToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generatedCode, forType: .string)
    }

    // MARK: - Helpers

    /// Pulls the root view name out of partial code so the UI can show it while streaming.
    private static func extractViewName(from code: String) -> String? {
        for line in code.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("struct ") else { continue }
            // struct <Name>: View / struct <Name> : View
            let afterStruct = trimmed.dropFirst("struct ".count)
            let name = afterStruct.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            if afterStruct.contains("View"), !name.isEmpty {
                return String(name)
            }
        }
        return nil
    }
}
