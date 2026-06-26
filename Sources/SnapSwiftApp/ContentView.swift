import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel = AppViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                ImagePanel(viewModel: viewModel)
                    .frame(minWidth: 320)
                CodePanel(viewModel: viewModel)
                    .frame(minWidth: 380)
            }
            Divider()
            StatusBar(viewModel: viewModel)
        }
    }
}

// MARK: - Left: image drop / preview

private struct ImagePanel: View {
    @Bindable var viewModel: AppViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: viewModel.image == nil ? [8] : [])
                    )
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.4))

                if let image = viewModel.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("Drop a UI screenshot here")
                            .font(.headline)
                        Text("PNG · JPEG · HEIC · TIFF")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .onDrop(of: [.fileURL, .image], isTargeted: $isTargeted) { providers in
                handleDrop(providers)
            }

            HStack {
                Button {
                    viewModel.openImagePicker()
                } label: {
                    Label("Choose Image…", systemImage: "folder")
                }

                Spacer()

                if viewModel.isWorking {
                    Button(role: .cancel) {
                        viewModel.cancel()
                    } label: {
                        Label("Cancel", systemImage: "stop.fill")
                    }
                } else {
                    Button {
                        viewModel.generate()
                    } label: {
                        Label("Generate SwiftUI", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canGenerate)
                }
            }

            HStack {
                Image(systemName: "text.bubble")
                    .foregroundStyle(.secondary)
                TextField("Optional hint (e.g. \"use a dark theme\")", text: $viewModel.hint)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(16)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in viewModel.loadImage(at: url) }
            }
            return true
        }
        if provider.canLoadObject(ofClass: NSImage.self) {
            _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                guard let image = object as? NSImage else { return }
                Task { @MainActor in viewModel.setImage(image) }
            }
            return true
        }
        return false
    }
}

// MARK: - Right: generated code

private struct CodePanel: View {
    @Bindable var viewModel: AppViewModel
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.viewName.isEmpty ? "Generated SwiftUI" : viewModel.viewName)
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.copyCodeToPasteboard()
                    withAnimation { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation { copied = false }
                    }
                } label: {
                    Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .disabled(!viewModel.hasResult)
            }
            .padding(12)

            Divider()

            ScrollView([.vertical, .horizontal]) {
                Text(viewModel.generatedCode.isEmpty ? placeholder : viewModel.generatedCode)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(viewModel.generatedCode.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var placeholder: String {
        "// Generated SwiftUI will appear here.\n// Drop a screenshot, then press “Generate SwiftUI”."
    }
}

// MARK: - Bottom: status + progress

private struct StatusBar: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 6) {
            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
                .opacity(viewModel.isWorking || viewModel.stage == .completed ? 1 : 0.25)

            HStack(spacing: 8) {
                if viewModel.isWorking {
                    ProgressView()
                        .controlSize(.small)
                }
                if let error = viewModel.errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                } else {
                    Text(viewModel.statusMessage)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .font(.callout)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 680)
}
