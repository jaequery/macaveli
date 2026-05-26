import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - AnnotatorState

/// State container passed down to the canvas via `@Binding`.
class AnnotatorState: ObservableObject {
    @Published var cgImage: CGImage?
    @Published var annotations: [Annotation] = []
    @Published var redoStack: [Annotation]   = []
    @Published var activeTool: AnnotationTool = .pencil
    @Published var activeStyle: AnnotationStyle = .defaultStyle
    @Published var selectedAnnotationID: UUID? = nil
    /// Published by `AnnotatorCanvas` once it knows its actual display rect.
    /// Used by `copyAndClose` to derive the correct canvas size for export.
    @Published var displayedSize: CGSize = .zero

    func loadImage(_ image: CGImage) {
        cgImage = image
        annotations = []
        redoStack   = []
        selectedAnnotationID = nil
    }

    func commitAnnotation(_ annotation: Annotation) {
        annotations.append(annotation)
        redoStack.removeAll()
    }

    func undo() {
        guard let last = annotations.popLast() else { return }
        if last.id == selectedAnnotationID { selectedAnnotationID = nil }
        redoStack.append(last)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        annotations.append(next)
    }

    /// Removes the currently selected annotation (if any) and clears selection.
    func deleteSelection() {
        guard let id = selectedAnnotationID,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        annotations.remove(at: index)
        selectedAnnotationID = nil
    }
}

// MARK: - AnnotatorView

/// Root SwiftUI view for the annotator window, hosted by `AnnotatorWindow`.
///
/// Layout: toolbar row (40 pt) on top, then either the annotation canvas
/// (image loaded) or the drop-zone empty state below.
///
/// Keyboard shortcuts:
///   ⌘Z      — undo the most recent annotation
///   ⇧⌘Z     — redo
///   ⌘↩      — copy flattened PNG to clipboard, close window
///   ⎋       — close without writing
///   1–5     — switch active tool (pencil/circle/rectangle/arrow/text)
///   S       — switch to the select tool
///   ⌫       — delete the currently selected annotation
struct AnnotatorView: View {
    @StateObject private var state: AnnotatorState
    @State private var isDragTargeted = false
    @State private var copyError: String? = nil

    init(initialImage: CGImage?) {
        let s = AnnotatorState()
        s.cgImage = initialImage
        _state = StateObject(wrappedValue: s)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                AnnotatorToolbar(
                    tool: $state.activeTool,
                    style: $state.activeStyle,
                    canUndo: !state.annotations.isEmpty,
                    canRedo: !state.redoStack.isEmpty,
                    onUndo: { state.undo() },
                    onRedo: { state.redo() },
                    onSave: saveToDisk,
                    onCopy: copyAndClose,
                    onClose: closeWindow
                )

                canvasOrDropZone
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(NSColor.windowBackgroundColor))
            // ⌘Z / ⇧⌘Z via hidden buttons so they fire through SwiftUI's focus system
            .background(undoRedoButtons)
            // Number-key tool switching + S = select + ⌫ = delete selection
            .background(toolSwitchButtons)
            .background(deleteSelectionButton)
            // ⌘V paste when canvas/drop-zone has focus
            .onPasteCommand(
                of: [
                    UTType.image.identifier,
                    UTType.fileURL.identifier,
                    UTType.png.identifier,
                    UTType.jpeg.identifier,
                    UTType.tiff.identifier,
                    UTType.heic.identifier,
                ]
            ) { providers in
                loadDroppedImage(providers: providers)
            }

            // Transient error banner — appears when copy fails.
            if let errorMsg = copyError {
                Text(errorMsg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.red.opacity(0.9))
                    )
                    .padding(.bottom, 16)
                    .transition(.opacity)
                    .zIndex(1)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            AnnotatorManager.shared.register(state: state)
        }
    }

    // MARK: - Canvas / drop-zone

    @ViewBuilder
    private var canvasOrDropZone: some View {
        if state.cgImage != nil {
            AnnotatorCanvas(
                state: state,
                cgImage: $state.cgImage,
                annotations: $state.annotations,
                activeTool: $state.activeTool,
                activeStyle: $state.activeStyle,
                commitAnnotation: { state.commitAnnotation($0) }
            )
        } else {
            AnnotatorDropZone(isDragTargeted: isDragTargeted)
                .onDrop(
                    of: [UTType.image, UTType.fileURL],
                    isTargeted: $isDragTargeted
                ) { providers in
                    loadDroppedImage(providers: providers)
                }
        }
    }

    // MARK: - Hidden keyboard-shortcut buttons

    private var undoRedoButtons: some View {
        Group {
            Button("") { state.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .frame(width: 0, height: 0)
                .hidden()
            Button("") { state.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .frame(width: 0, height: 0)
                .hidden()
        }
    }

    private var toolSwitchButtons: some View {
        Group {
            Button("") { state.activeTool = .pencil }
                .keyboardShortcut("1", modifiers: [])
                .frame(width: 0, height: 0)
                .hidden()
            Button("") { state.activeTool = .circle }
                .keyboardShortcut("2", modifiers: [])
                .frame(width: 0, height: 0)
                .hidden()
            Button("") { state.activeTool = .rectangle }
                .keyboardShortcut("3", modifiers: [])
                .frame(width: 0, height: 0)
                .hidden()
            Button("") { state.activeTool = .arrow }
                .keyboardShortcut("4", modifiers: [])
                .frame(width: 0, height: 0)
                .hidden()
            Button("") { state.activeTool = .text }
                .keyboardShortcut("5", modifiers: [])
                .frame(width: 0, height: 0)
                .hidden()
            Button("") { state.activeTool = .select }
                .keyboardShortcut("s", modifiers: [])
                .frame(width: 0, height: 0)
                .hidden()
        }
    }

    private var deleteSelectionButton: some View {
        Button("") { state.deleteSelection() }
            .keyboardShortcut(.delete, modifiers: [])
            .frame(width: 0, height: 0)
            .hidden()
    }

    // MARK: - Actions

    private func copyAndClose() {
        guard let cgImage = state.cgImage else {
            closeWindow()
            return
        }
        let canvasSize = state.displayedSize
        guard let data = AnnotatorManager.shared.flattenToPNG(
            image: cgImage,
            annotations: state.annotations,
            canvasSize: canvasSize
        ) else {
            showCopyError("Could not render image for export.")
            return
        }
        guard AnnotatorManager.shared.writePNGToClipboard(data: data) else {
            showCopyError("Could not write image to clipboard.")
            return
        }
        closeWindow()
    }

    private func saveToDisk() {
        guard let cgImage = state.cgImage else {
            closeWindow()
            return
        }
        let canvasSize = state.displayedSize
        guard let data = AnnotatorManager.shared.flattenToPNG(
            image: cgImage,
            annotations: state.annotations,
            canvasSize: canvasSize
        ) else {
            showCopyError("Could not render image for export.")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedFileName()
        if let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            panel.directoryURL = desktop
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            // User cancelled — leave the window open.
            return
        }
        guard AnnotatorManager.shared.writePNGToFile(data: data, to: url) else {
            showCopyError("Could not save image to disk.")
            return
        }
        closeWindow()
    }

    private func suggestedFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "Macaveli-Annotated-\(formatter.string(from: Date())).png"
    }

    private func showCopyError(_ message: String) {
        copyError = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            copyError = nil
        }
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }

    // MARK: - Image loading (drop / paste)

    @discardableResult
    private func loadDroppedImage(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          url.isFileURL, url.scheme == "file" else { return }
                    loadImageFromURL(url)
                }
                return true
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data else { return }
                    loadImageFromData(data)
                }
                return true
            }
        }
        return false
    }

    private func loadImageFromURL(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        let supported = ["png", "jpg", "jpeg", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp"]
        guard supported.contains(ext) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
            DispatchQueue.main.async { state.loadImage(cgImage) }
        }
    }

    private func loadImageFromData(_ data: Data) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
            DispatchQueue.main.async { state.loadImage(cgImage) }
        }
    }

}

// MARK: - Drop zone

struct AnnotatorDropZone: View {
    let isDragTargeted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color(NSColor.textBackgroundColor)

            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        isDragTargeted
                            ? Color.accentColor.opacity(0.8)
                            : Color.secondary.opacity(0.5)
                    )
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: isDragTargeted)

                Text("Drop an image to annotate")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("or press ⌘V to paste from the clipboard")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isDragTargeted ? Color.accentColor : Color.primary.opacity(0.18),
                        style: StrokeStyle(lineWidth: isDragTargeted ? 2 : 1.5, dash: [8, 5])
                    )
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: isDragTargeted)
            )
            .padding(40)
        }
        .accessibilityLabel("Drop an image here to annotate it, or press Command V to paste from the clipboard")
    }
}

// MARK: - Preview

#Preview("Drop zone") {
    AnnotatorView(initialImage: nil)
        .frame(width: 1000, height: 700)
}
