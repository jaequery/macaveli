import SwiftUI
import AppKit

// MARK: - AnnotatorCanvas
//
// Owned by: Senior Developer
//
// The canvas drawing surface embedded inside `AnnotatorView`.
//
// Bindings contract (caller is `AnnotatorView`):
//   cgImage          — the source image; nil = show drop-zone
//   annotations      — committed, ordered list of annotations
//   activeTool       — currently selected drawing tool
//   activeStyle      — color + strokeWidth for new annotations
//   commitAnnotation — closure: called with a fully-constructed Annotation
//                      when the user finishes a drag or submits a text field.
//                      Caller (AnnotatorView) appends to its own list and
//                      clears the redo stack.
//
// Coordinate system:
//   All annotation coordinates are stored in "canvas logical space":
//   top-left origin, matching the `displayedRect` computed here.
//   The export path in AnnotatorManager scales these to pixel coordinates.

struct AnnotatorCanvas: View {
    @ObservedObject var state: AnnotatorState
    @Binding var cgImage: CGImage?
    @Binding var annotations: [Annotation]
    @Binding var activeTool: AnnotationTool
    @Binding var activeStyle: AnnotationStyle
    var commitAnnotation: (Annotation) -> Void

    // Draft (in-progress) shape state — not committed until drag ends.
    @State private var draftPoints: [CGPoint] = []
    @State private var draftStart:  CGPoint   = .zero
    @State private var draftEnd:    CGPoint   = .zero
    @State private var isDragging:  Bool      = false

    // Text-tool overlay state.
    @State private var textOverlayOrigin: CGPoint? = nil
    @State private var textOverlayValue:  String   = ""
    @FocusState private var textFieldFocused: Bool

    // The rect where the image is actually rendered inside the canvas bounds.
    // Updated every layout pass via a GeometryReader.
    @State private var displayedRect: CGRect = .zero

    var body: some View {
        GeometryReader { geo in
            let bounds = geo.frame(in: .local)
            let imgRect = imageRect(in: bounds.size)

            ZStack {
                // Background.
                Color(NSColor.windowBackgroundColor)

                if let cg = cgImage {
                    // Base image + annotations rendered with SwiftUI Canvas.
                    Canvas { context, size in
                        // 1. Base image.
                        let uiImage = Image(decorative: cg, scale: 1, orientation: .up)
                        context.draw(uiImage, in: imgRect)

                        // 2. Committed annotations.
                        for annotation in annotations {
                            drawAnnotation(annotation, in: &context, rect: imgRect)
                        }

                        // 3. In-progress draft.
                        if isDragging {
                            drawDraft(in: &context, rect: imgRect, style: activeStyle)
                        }
                    }
                    .frame(width: bounds.width, height: bounds.height)
                    // Allow swapping the image by dropping a new one over the canvas.
                    .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
                        handleDrop(providers: providers)
                        return true
                    }
                }

                // Text-tool overlay.
                if activeTool == .text, let origin = textOverlayOrigin {
                    TextField("", text: $textOverlayValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: activeStyle.strokeWidth * 3 + 10, weight: .semibold))
                        .foregroundColor(activeStyle.color)
                        .frame(width: 200, alignment: .leading)
                        .focused($textFieldFocused)
                        .position(x: origin.x + 100, y: origin.y)
                        .onSubmit { commitTextOverlay(at: origin) }
                        .onChange(of: textFieldFocused) { focused in
                            if !focused { commitTextOverlay(at: origin) }
                        }
                }
            }
            // Drag gesture for drawing tools (all except text).
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        guard activeTool != .text else { return }
                        let pt = clampedPoint(value.location, to: imgRect)
                        if !isDragging {
                            draftStart  = pt
                            draftPoints = [pt]
                            isDragging  = true
                        } else {
                            // Soft cap on pencil points to prevent unbounded
                            // memory growth on ProMotion (120 Hz) long-drag input.
                            if activeTool == .pencil, draftPoints.count < 4000 {
                                draftPoints.append(pt)
                            }
                            draftEnd = pt
                        }
                    }
                    .onEnded { value in
                        guard activeTool != .text, isDragging else { return }
                        let pt = clampedPoint(value.location, to: imgRect)
                        draftEnd = pt

                        let localStart = toLocalCoords(draftStart, imageRect: imgRect)
                        let localEnd   = toLocalCoords(draftEnd,   imageRect: imgRect)
                        let localPoints = draftPoints.map { toLocalCoords($0, imageRect: imgRect) }

                        let newAnnotation: Annotation
                        let id = UUID()
                        switch activeTool {
                        case .pencil:
                            newAnnotation = .pencil(id: id,
                                                    points: localPoints.count > 1 ? localPoints : [localStart, localEnd],
                                                    style: activeStyle)
                        case .circle:
                            newAnnotation = .circle(id: id,
                                                    rect: rectFromPoints(localStart, localEnd),
                                                    style: activeStyle)
                        case .rectangle:
                            newAnnotation = .rectangle(id: id,
                                                       rect: rectFromPoints(localStart, localEnd),
                                                       style: activeStyle)
                        case .arrow:
                            newAnnotation = .arrow(id: id,
                                                   from: localStart,
                                                   to: localEnd,
                                                   style: activeStyle)
                        case .text:
                            // Handled by tap gesture below.
                            draftPoints.removeAll()
                            isDragging = false
                            return
                        }

                        // Only commit non-trivial annotations (avoid 0-length shapes).
                        let dist = distance(draftStart, draftEnd)
                        if dist > 2 || activeTool == .pencil {
                            commitAnnotation(newAnnotation)
                        }
                        draftPoints.removeAll()
                        isDragging = false
                    }
            )
            // Text tool: single tap places the overlay.
            .onTapGesture { location in
                guard activeTool == .text else { return }
                guard imageRect(in: bounds.size).contains(location) else { return }
                // If a text overlay is already open, commit it first.
                if let origin = textOverlayOrigin, !textOverlayValue.isEmpty {
                    commitTextOverlay(at: origin)
                }
                textOverlayOrigin = location
                textOverlayValue  = ""
                textFieldFocused  = true
            }
            .onAppear {
                displayedRect = imgRect
                state.displayedSize = imgRect.size
            }
            .onChange(of: bounds.size) { _ in
                let rect = imageRect(in: bounds.size)
                displayedRect = rect
                state.displayedSize = rect.size
            }
        }
    }

    // MARK: - Geometry helpers

    /// Returns the rect within `size` that the image occupies (aspect-fit).
    private func imageRect(in size: CGSize) -> CGRect {
        guard let cg = cgImage, cg.width > 0, cg.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }
        let imgAspect = CGFloat(cg.width) / CGFloat(cg.height)
        let boundsAspect = size.width / size.height
        if imgAspect > boundsAspect {
            let h = size.width / imgAspect
            return CGRect(x: 0, y: (size.height - h) / 2, width: size.width, height: h)
        } else {
            let w = size.height * imgAspect
            return CGRect(x: (size.width - w) / 2, y: 0, width: w, height: size.height)
        }
    }

    /// Clamps `point` to remain within `rect`.
    private func clampedPoint(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    /// Converts a canvas-space point to image-local coordinates
    /// (origin top-left of the displayed image rect).
    private func toLocalCoords(_ point: CGPoint, imageRect: CGRect) -> CGPoint {
        CGPoint(
            x: point.x - imageRect.minX,
            y: point.y - imageRect.minY
        )
    }

    private func rectFromPoints(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x; let dy = b.y - a.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Text overlay commit

    private func commitTextOverlay(at origin: CGPoint) {
        defer {
            textOverlayOrigin = nil
            textOverlayValue  = ""
            textFieldFocused  = false
        }
        let trimmed = textOverlayValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let imgRect = displayedRect
        let localOrigin = toLocalCoords(origin, imageRect: imgRect)
        let fontSize: CGFloat = activeStyle.strokeWidth * 3 + 10
        commitAnnotation(.text(id: UUID(),
                               origin: localOrigin,
                               string: trimmed,
                               style: activeStyle,
                               fontSize: fontSize))
    }

    // MARK: - Drop handling

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    guard let nsImage = image as? NSImage else { return }
                    DispatchQueue.main.async {
                        loadNSImage(nsImage)
                    }
                }
                return
            }
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          url.isFileURL, url.scheme == "file",
                          let nsImage = NSImage(contentsOf: url) else { return }
                    DispatchQueue.main.async {
                        loadNSImage(nsImage)
                    }
                }
                return
            }
        }
    }

    private func loadNSImage(_ nsImage: NSImage) {
        guard let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        state.loadImage(cg)
    }

    // MARK: - Canvas drawing helpers

    private func drawAnnotation(_ annotation: Annotation,
                                 in context: inout GraphicsContext,
                                 rect: CGRect) {
        let style = annotation.style

        switch annotation {

        case .pencil(_, let points, _):
            guard points.count > 1 else { return }
            var path = Path()
            path.move(to: toCanvasCoords(points[0], imageRect: rect))
            for pt in points.dropFirst() {
                path.addLine(to: toCanvasCoords(pt, imageRect: rect))
            }
            context.stroke(path,
                           with: .color(style.color),
                           style: StrokeStyle(lineWidth: style.strokeWidth,
                                              lineCap: .round,
                                              lineJoin: .round))

        case .circle(_, let r, _):
            let canvasRect = toCanvasRect(r, imageRect: rect)
            let path = Path(ellipseIn: canvasRect)
            context.stroke(path,
                           with: .color(style.color),
                           lineWidth: style.strokeWidth)

        case .rectangle(_, let r, _):
            let canvasRect = toCanvasRect(r, imageRect: rect)
            let path = Path(canvasRect)
            context.stroke(path,
                           with: .color(style.color),
                           lineWidth: style.strokeWidth)

        case .arrow(_, let from, let to, _):
            let canvasFrom = toCanvasCoords(from, imageRect: rect)
            let canvasTo   = toCanvasCoords(to,   imageRect: rect)
            drawCanvasArrow(from: canvasFrom,
                            to: canvasTo,
                            style: style,
                            in: &context)

        case .text(_, let origin, let string, let style, let fontSize):
            let canvasOrigin = toCanvasCoords(origin, imageRect: rect)
            context.draw(
                Text(string)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundColor(style.color),
                at: canvasOrigin,
                anchor: .topLeading
            )
        }
    }

    private func drawDraft(in context: inout GraphicsContext,
                            rect: CGRect,
                            style: AnnotationStyle) {
        switch activeTool {
        case .pencil:
            guard draftPoints.count > 1 else { return }
            var path = Path()
            path.move(to: draftPoints[0])
            for pt in draftPoints.dropFirst() {
                path.addLine(to: pt)
            }
            context.stroke(path,
                           with: .color(style.color.opacity(0.85)),
                           style: StrokeStyle(lineWidth: style.strokeWidth,
                                              lineCap: .round,
                                              lineJoin: .round))

        case .circle:
            let r = rectFromPoints(draftStart, draftEnd)
            let path = Path(ellipseIn: r)
            context.stroke(path,
                           with: .color(style.color.opacity(0.85)),
                           lineWidth: style.strokeWidth)

        case .rectangle:
            let r = rectFromPoints(draftStart, draftEnd)
            let path = Path(r)
            context.stroke(path,
                           with: .color(style.color.opacity(0.85)),
                           lineWidth: style.strokeWidth)

        case .arrow:
            drawCanvasArrow(from: draftStart,
                            to: draftEnd,
                            style: style,
                            in: &context,
                            alpha: 0.85)

        case .text:
            break
        }
    }

    private func drawCanvasArrow(from: CGPoint,
                                  to: CGPoint,
                                  style: AnnotationStyle,
                                  in context: inout GraphicsContext,
                                  alpha: Double = 1.0) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = sqrt(dx * dx + dy * dy)

        if len < 8 {
            // Too short — just a line.
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)
            context.stroke(path,
                           with: .color(style.color.opacity(alpha)),
                           lineWidth: style.strokeWidth)
            return
        }

        let angle = atan2(dy, dx)
        let headLength = min(style.strokeWidth * 4, len * 0.4)
        let headAngle: CGFloat = .pi / 6

        let shaftEnd = CGPoint(
            x: to.x - headLength * cos(angle),
            y: to.y - headLength * sin(angle)
        )

        // Shaft.
        var shaft = Path()
        shaft.move(to: from)
        shaft.addLine(to: shaftEnd)
        context.stroke(shaft,
                       with: .color(style.color.opacity(alpha)),
                       style: StrokeStyle(lineWidth: style.strokeWidth,
                                          lineCap: .round))

        // Arrowhead.
        let left  = CGPoint(x: to.x - headLength * cos(angle - headAngle),
                             y: to.y - headLength * sin(angle - headAngle))
        let right = CGPoint(x: to.x - headLength * cos(angle + headAngle),
                             y: to.y - headLength * sin(angle + headAngle))
        var head = Path()
        head.move(to: to)
        head.addLine(to: left)
        head.addLine(to: right)
        head.closeSubpath()
        context.fill(head, with: .color(style.color.opacity(alpha)))
    }

    // MARK: - Coordinate conversion (local → canvas)

    private func toCanvasCoords(_ point: CGPoint, imageRect: CGRect) -> CGPoint {
        CGPoint(x: point.x + imageRect.minX,
                y: point.y + imageRect.minY)
    }

    private func toCanvasRect(_ rect: CGRect, imageRect: CGRect) -> CGRect {
        CGRect(x: rect.minX + imageRect.minX,
               y: rect.minY + imageRect.minY,
               width: rect.width,
               height: rect.height)
    }
}
