import AppKit
import SwiftUI
import ImageIO

/// Manages the single annotator window.
///
/// - `openFromClipboard()` reads `NSPasteboard.general` for an image.
///   If found, a new (or re-used) window is opened with that image.
///   If not found, the window opens in a drop-zone / empty state.
/// - Repeated calls while the window is alive bring it to front and
///   replace the current image if the clipboard content has changed.
/// - `flattenToPNG` and `writePNGToClipboard` are the export surface
///   called by the annotator view's "Copy" action.
final class AnnotatorManager {
    static let shared = AnnotatorManager()

    private var windowController: NSWindowController?

    private init() {}

    // MARK: - Open

    @MainActor
    func openFromClipboard() {
        let image = imageFromPasteboard()

        if let wc = windowController, let window = wc.window, window.isVisible {
            // Window already open — update image if clipboard changed, then focus.
            if let hostingView = window.contentView as? NSHostingView<AnnotatorView>,
               let newImage = image {
                hostingView.rootView.loadImage(newImage)
            }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Build a fresh window.
        let view = AnnotatorView(initialImage: image)
        let window = AnnotatorWindow.makeWindow(rootView: view)
        window.delegate = AnnotatorWindowDelegate.shared
        let wc = NSWindowController(window: window)
        self.windowController = wc
        NSApp.activate(ignoringOtherApps: true)
        wc.showWindow(nil)
        window.center()
    }

    // MARK: - Close (called by window delegate)

    @MainActor
    func clearWindowReference() {
        windowController = nil
    }

    // MARK: - Clipboard image reading

    /// Reads `NSPasteboard.general` for an image.
    /// Prefers `NSImage(pasteboard:)`, then falls back to a `.fileURL`
    /// pointing at a recognized image file.  Returns `nil` if nothing
    /// usable is found — callers should open in drop-zone state.
    private func imageFromPasteboard() -> CGImage? {
        let pb = NSPasteboard.general

        // Primary: let AppKit figure out the image type.
        if let nsImage = NSImage(pasteboard: pb) {
            return normalizedCGImage(from: nsImage)
        }

        // Fallback: a file URL for a common image type.
        if let url = pb.readObjects(forClasses: [NSURL.self],
                                    options: [.urlReadingFileURLsOnly: true])?.first as? URL {
            let imageExtensions = ["png", "jpg", "jpeg", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp"]
            if imageExtensions.contains(url.pathExtension.lowercased()) {
                if let nsImage = NSImage(contentsOf: url) {
                    return normalizedCGImage(from: nsImage)
                }
            }
        }

        return nil
    }

    /// Normalizes an `NSImage` to a pixel-correct `CGImage` that honors
    /// EXIF orientation so the canvas-displayed pixels match the exported
    /// result.  Uses `CGImageSource` to read raw pixel data when possible.
    private func normalizedCGImage(from nsImage: NSImage) -> CGImage? {
        // Try to get the raw CGImage representation to avoid NSImage
        // applying any display-only transforms.
        if let cgImage = nsImage.cgImage(forProposedRect: nil,
                                          context: nil,
                                          hints: nil) {
            return cgImage
        }
        // Last resort: render into a bitmap at the image's natural size.
        guard let rep = nsImage.bestRepresentation(for: NSRect(origin: .zero, size: nsImage.size),
                                                    context: nil,
                                                    hints: nil) as? NSBitmapImageRep else {
            return nil
        }
        return rep.cgImage
    }

    // MARK: - Export

    /// Flattens the base image and all annotations into a PNG-encoded
    /// `Data` at the source image's native pixel resolution.
    ///
    /// - Parameters:
    ///   - image: The source `CGImage` (pixel resolution).
    ///   - annotations: The committed annotations in draw order.
    ///   - canvasSize: The logical size of the displayed image rect in the
    ///     SwiftUI canvas (points, top-left origin).
    /// - Returns: PNG-encoded `Data`, or `nil` if the context could not be
    ///   created.
    func flattenToPNG(image: CGImage,
                      annotations: [Annotation],
                      canvasSize: CGSize) -> Data? {
        let pixelWidth  = image.width
        let pixelHeight = image.height

        guard pixelWidth > 0, pixelHeight > 0,
              canvasSize.width > 0, canvasSize.height > 0 else { return nil }

        let scale = CGFloat(pixelWidth) / canvasSize.width

        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // CGContext has origin bottom-left; flip to top-left so annotation
        // coordinates (top-left logical) map correctly.
        ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
        ctx.scaleBy(x: 1, y: -1)

        // Draw the base image.
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        // Draw each annotation scaled from logical → pixel coordinates.
        for annotation in annotations {
            drawAnnotation(annotation, in: ctx, scale: scale)
        }

        guard let outputImage = ctx.makeImage() else { return nil }

        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            mutableData,
            "public.png" as CFString,
            1,
            nil
        ) else { return nil }

        CGImageDestinationAddImage(dest, outputImage, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }

        return mutableData as Data
    }

    /// Writes PNG data (plus a TIFF fallback) to the system pasteboard.
    func writePNGToClipboard(data: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(data, forType: .png)

        // Legacy TIFF for compatibility with older apps.
        if let image = NSImage(data: data) {
            if let tiffData = image.tiffRepresentation {
                pb.setData(tiffData, forType: .tiff)
            }
        }
    }

    // MARK: - CGContext drawing

    private func drawAnnotation(_ annotation: Annotation,
                                 in ctx: CGContext,
                                 scale: CGFloat) {
        let style = annotation.style
        let lineWidth = style.strokeWidth * scale
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(nsColor(from: style.color).cgColor)
        ctx.setFillColor(nsColor(from: style.color).cgColor)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        switch annotation {

        case .pencil(_, let points, _):
            guard points.count > 1 else { return }
            ctx.beginPath()
            ctx.move(to: scaled(points[0], by: scale))
            for pt in points.dropFirst() {
                ctx.addLine(to: scaled(pt, by: scale))
            }
            ctx.strokePath()

        case .circle(_, let rect, _):
            let scaledRect = CGRect(
                x: rect.minX * scale,
                y: rect.minY * scale,
                width: rect.width * scale,
                height: rect.height * scale
            )
            ctx.strokeEllipse(in: scaledRect)

        case .rectangle(_, let rect, _):
            let scaledRect = CGRect(
                x: rect.minX * scale,
                y: rect.minY * scale,
                width: rect.width * scale,
                height: rect.height * scale
            )
            ctx.stroke(scaledRect)

        case .arrow(_, let from, let to, _):
            let scaledFrom = scaled(from, by: scale)
            let scaledTo   = scaled(to, by: scale)
            drawArrow(ctx: ctx,
                      from: scaledFrom,
                      to: scaledTo,
                      lineWidth: lineWidth)

        case .text(_, let origin, let string, let style, let fontSize):
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize * scale, weight: .semibold),
                .foregroundColor: nsColor(from: style.color),
            ]
            let attrStr = NSAttributedString(string: string, attributes: attributes)
            let scaledOrigin = scaled(origin, by: scale)
            // CGContext is flipped; NSAttributedString.draw uses a flipped
            // context so we flip back momentarily.
            ctx.saveGState()
            ctx.translateBy(x: scaledOrigin.x, y: scaledOrigin.y)
            ctx.scaleBy(x: 1, y: -1)
            attrStr.draw(at: .zero)
            ctx.restoreGState()
        }
    }

    private func drawArrow(ctx: CGContext,
                            from: CGPoint,
                            to: CGPoint,
                            lineWidth: CGFloat) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 8 else {
            // Segment too short — just draw the line, skip the arrowhead.
            ctx.beginPath()
            ctx.move(to: from)
            ctx.addLine(to: to)
            ctx.strokePath()
            return
        }

        let headLength = min(lineWidth * 4, length * 0.4)
        let angle = atan2(dy, dx)
        let headAngle: CGFloat = .pi / 6  // 30°

        // Shaft end: pull back by headLength so the shaft doesn't poke
        // through the filled triangle head.
        let shaftEnd = CGPoint(
            x: to.x - headLength * cos(angle),
            y: to.y - headLength * sin(angle)
        )

        // Shaft.
        ctx.beginPath()
        ctx.move(to: from)
        ctx.addLine(to: shaftEnd)
        ctx.strokePath()

        // Arrowhead (filled triangle).
        let left = CGPoint(
            x: to.x - headLength * cos(angle - headAngle),
            y: to.y - headLength * sin(angle - headAngle)
        )
        let right = CGPoint(
            x: to.x - headLength * cos(angle + headAngle),
            y: to.y - headLength * sin(angle + headAngle)
        )
        ctx.beginPath()
        ctx.move(to: to)
        ctx.addLine(to: left)
        ctx.addLine(to: right)
        ctx.closePath()
        ctx.fillPath()
    }

    // MARK: - Helpers

    private func scaled(_ point: CGPoint, by scale: CGFloat) -> CGPoint {
        CGPoint(x: point.x * scale, y: point.y * scale)
    }

    /// Converts a SwiftUI `Color` to an `NSColor`.
    /// This works on macOS 13+ via the `resolve(in:)` path or direct init.
    private func nsColor(from color: Color) -> NSColor {
        NSColor(color)
    }
}

// MARK: - Window delegate

/// Clears `AnnotatorManager`'s window reference when the annotator window
/// closes so the next ⌃⌘A invocation opens a fresh window.
final class AnnotatorWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = AnnotatorWindowDelegate()

    private override init() {}

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            AnnotatorManager.shared.clearWindowReference()
        }
    }
}
