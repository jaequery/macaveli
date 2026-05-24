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

    func loadImage(_ image: CGImage) {
        cgImage = image
        annotations = []
        redoStack   = []
    }

    func commitAnnotation(_ annotation: Annotation) {
        annotations.append(annotation)
        redoStack.removeAll()
    }

    func undo() {
        guard let last = annotations.popLast() else { return }
        redoStack.append(last)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        annotations.append(next)
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
struct AnnotatorView: View {
    @StateObject private var state: AnnotatorState
    @State private var isDragTargeted = false

    init(initialImage: CGImage?) {
        let s = AnnotatorState()
        s.cgImage = initialImage
        _state = StateObject(wrappedValue: s)
    }

    /// Called by `AnnotatorManager` when ⌃⌘A fires while the window is open
    /// and the clipboard image has changed.
    func loadImage(_ image: CGImage) {
        state.loadImage(image)
    }

    var body: some View {
        VStack(spacing: 0) {
            AnnotatorToolbar(
                tool: $state.activeTool,
                style: $state.activeStyle,
                canUndo: !state.annotations.isEmpty,
                canRedo: !state.redoStack.isEmpty,
                onUndo: { state.undo() },
                onRedo: { state.redo() },
                onCopy: copyAndClose,
                onClose: closeWindow
            )

            canvasOrDropZone
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
        // ⌘Z / ⇧⌘Z via hidden buttons so they fire through SwiftUI's focus system
        .background(undoRedoButtons)
        // Number-key tool switching
        .background(toolSwitchButtons)
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
    }

    // MARK: - Canvas / drop-zone

    @ViewBuilder
    private var canvasOrDropZone: some View {
        if state.cgImage != nil {
            AnnotatorCanvas(
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
        }
    }

    // MARK: - Actions

    private func copyAndClose() {
        guard let cgImage = state.cgImage else {
            closeWindow()
            return
        }
        let canvasSize = derivedCanvasSize(for: cgImage)
        if let data = AnnotatorManager.shared.flattenToPNG(
            image: cgImage,
            annotations: state.annotations,
            canvasSize: canvasSize
        ) {
            AnnotatorManager.shared.writePNGToClipboard(data: data)
        }
        closeWindow()
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }

    private func derivedCanvasSize(for image: CGImage) -> CGSize {
        guard let window = NSApp.keyWindow else {
            return CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
        }
        // Subtract the toolbar height (40 pt) from the available content area.
        let toolbarHeight: CGFloat = 40
        let winSize = window.contentView?.bounds.size ?? window.frame.size
        let availableSize = CGSize(
            width: winSize.width,
            height: max(winSize.height - toolbarHeight, 1)
        )
        let imageAspect = CGFloat(image.width) / CGFloat(image.height)
        let winAspect   = availableSize.width / availableSize.height
        if imageAspect > winAspect {
            let h = availableSize.width / imageAspect
            return CGSize(width: availableSize.width, height: h)
        } else {
            let w = availableSize.height * imageAspect
            return CGSize(width: w, height: availableSize.height)
        }
    }

    // MARK: - Image loading (drop / paste)

    @discardableResult
    private func loadDroppedImage(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
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
            DispatchQueue.main.async { state.cgImage = cgImage }
        }
    }

    private func loadImageFromData(_ data: Data) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
            DispatchQueue.main.async { state.cgImage = cgImage }
        }
    }

}

// MARK: - Drop zone

struct AnnotatorDropZone: View {
    let isDragTargeted: Bool

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
                    .animation(.easeInOut(duration: 0.16), value: isDragTargeted)

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
                    .animation(.easeInOut(duration: 0.16), value: isDragTargeted)
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
