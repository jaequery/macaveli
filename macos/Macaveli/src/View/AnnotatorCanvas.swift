import SwiftUI
import AppKit

// MARK: - AnnotatorCanvas
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
//
// Coordinate system:
//   Anchor coordinates are stored in "image-local space" — top-left origin
//   relative to the displayed image rect. Each Annotation also carries
//   `translation` and `rotation` (around its anchor center) which are
//   applied at render and export time.

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

    // Selection / manipulation state.
    private enum ManipulationMode { case idle, move, rotate, resize }
    @State private var manipulation: ManipulationMode = .idle
    @State private var manipStartTranslation: CGSize = .zero
    @State private var manipStartRotation:    CGFloat = 0
    @State private var manipStartScale:       CGFloat = 1
    @State private var manipStartLocation:    CGPoint = .zero
    @State private var manipStartCenter:      CGPoint = .zero
    @State private var manipStartHandleDist:  CGFloat = 1

    // The rect where the image is actually rendered inside the canvas bounds.
    @State private var displayedRect: CGRect = .zero

    private let rotateHandleOffset: CGFloat = 28
    private let rotateHandleRadius: CGFloat = 7
    private let cornerHandleRadius: CGFloat = 5
    /// Default point size used when committing a new text annotation.
    /// Placed text is intentionally small so it doesn't dominate screenshots;
    /// use the Select tool's corner handles to scale it up after placement.
    private let defaultTextFontSize: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            let bounds = geo.frame(in: .local)
            let imgRect = imageRect(in: bounds.size)

            ZStack {
                Color(NSColor.windowBackgroundColor)

                if let cg = cgImage {
                    Canvas { context, _ in
                        // 1. Base image.
                        let uiImage = Image(decorative: cg, scale: 1, orientation: .up)
                        context.draw(uiImage, in: imgRect)

                        // 2. Committed annotations (with their transforms).
                        for annotation in annotations {
                            drawAnnotation(annotation, in: &context, imageRect: imgRect)
                        }

                        // 3. In-progress draft.
                        if isDragging, activeTool != .select {
                            drawDraft(in: &context, style: activeStyle)
                        }

                        // 4. Selection overlay.
                        if activeTool == .select,
                           let id = state.selectedAnnotationID,
                           let annotation = annotations.first(where: { $0.id == id }) {
                            drawSelectionOverlay(for: annotation, in: &context, imageRect: imgRect)
                        }
                    }
                    .frame(width: bounds.width, height: bounds.height)
                    .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
                        handleDrop(providers: providers)
                        return true
                    }
                }

                if activeTool == .text, let origin = textOverlayOrigin {
                    TextField("", text: $textOverlayValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: defaultTextFontSize, weight: .semibold))
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
            .gesture(canvasDragGesture(imgRect: imgRect))
            .onAppear {
                displayedRect = imgRect
                state.displayedSize = imgRect.size
            }
            .onChange(of: bounds.size) { _ in
                let rect = imageRect(in: bounds.size)
                displayedRect = rect
                state.displayedSize = rect.size
            }
            .onChange(of: activeTool) { newTool in
                // Leaving select mode clears the selection.
                if newTool != .select { state.selectedAnnotationID = nil }
            }
        }
    }

    // MARK: - Gesture

    private func canvasDragGesture(imgRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if activeTool == .select {
                    handleSelectGestureChanged(value, imageRect: imgRect)
                    return
                }
                guard activeTool != .text else { return }
                let pt = clampedPoint(value.location, to: imgRect)
                if !isDragging {
                    draftStart  = pt
                    draftPoints = [pt]
                    isDragging  = true
                } else {
                    if activeTool == .pencil, draftPoints.count < 4000 {
                        draftPoints.append(pt)
                    }
                    draftEnd = pt
                }
            }
            .onEnded { value in
                if activeTool == .select {
                    handleSelectGestureEnded(value, imageRect: imgRect)
                    return
                }
                if activeTool == .text {
                    let location = clampedPoint(value.location, to: imgRect)
                    guard imgRect.contains(location) else { return }
                    if let origin = textOverlayOrigin, !textOverlayValue.isEmpty {
                        commitTextOverlay(at: origin)
                    }
                    textOverlayOrigin = location
                    textOverlayValue  = ""
                    textFieldFocused  = true
                    return
                }
                guard isDragging else { return }
                let pt = clampedPoint(value.location, to: imgRect)
                draftEnd = pt
                commitDraft(imageRect: imgRect)
                draftPoints.removeAll()
                isDragging = false
            }
    }

    // MARK: - Select-mode handling

    private func handleSelectGestureChanged(_ value: DragGesture.Value, imageRect: CGRect) {
        if manipulation == .idle {
            manipStartLocation = value.startLocation
            guard let id = state.selectedAnnotationID,
                  let annotation = annotations.first(where: { $0.id == id }) else {
                return
            }
            let center = transformedAnchorCenterCanvas(for: annotation, imageRect: imageRect)

            // 1. Rotate handle (above bbox).
            if let rotateHandle = rotateHandlePosition(for: annotation, imageRect: imageRect),
               distance(value.startLocation, rotateHandle) <= rotateHandleRadius + 4 {
                manipulation = .rotate
                manipStartRotation = annotation.rotation
                manipStartCenter = center
            }
            // 2. Any corner handle → resize.
            else if cornerHandlePositions(for: annotation, imageRect: imageRect)
                        .contains(where: { distance(value.startLocation, $0) <= cornerHandleRadius + 4 }) {
                manipulation = .resize
                manipStartScale = annotation.scale
                manipStartCenter = center
                manipStartHandleDist = max(distance(value.startLocation, center), 1)
            }
            // 3. Inside bbox → move.
            else if transformedBoundingBox(for: annotation, imageRect: imageRect)
                        .insetBy(dx: -4, dy: -4)
                        .contains(value.startLocation) {
                manipulation = .move
                manipStartTranslation = annotation.translation
            }
            // 4. Empty area: defer to .onEnded for click-to-deselect / click-to-select.
            else {
                return
            }
        }

        guard let id = state.selectedAnnotationID,
              let index = annotations.firstIndex(where: { $0.id == id }) else {
            return
        }

        switch manipulation {
        case .move:
            let dx = value.location.x - manipStartLocation.x
            let dy = value.location.y - manipStartLocation.y
            annotations[index].translation = CGSize(
                width:  manipStartTranslation.width  + dx,
                height: manipStartTranslation.height + dy
            )
        case .rotate:
            let startAngle = atan2(manipStartLocation.y - manipStartCenter.y,
                                   manipStartLocation.x - manipStartCenter.x)
            let currentAngle = atan2(value.location.y - manipStartCenter.y,
                                     value.location.x - manipStartCenter.x)
            annotations[index].rotation = manipStartRotation + (currentAngle - startAngle)
        case .resize:
            let currentDist = max(distance(value.location, manipStartCenter), 1)
            let raw = manipStartScale * currentDist / manipStartHandleDist
            annotations[index].scale = min(max(raw, 0.1), 10)
        case .idle:
            break
        }
    }

    private func handleSelectGestureEnded(_ value: DragGesture.Value, imageRect: CGRect) {
        defer {
            manipulation = .idle
        }

        // If we were actively manipulating, the change is already applied.
        if manipulation != .idle { return }

        // Otherwise this was a click. Hit-test annotations in reverse draw order
        // (topmost wins).
        let tap = value.location
        for annotation in annotations.reversed() {
            if hitTest(annotation, point: tap, imageRect: imageRect) {
                state.selectedAnnotationID = annotation.id
                return
            }
        }
        state.selectedAnnotationID = nil
    }

    // MARK: - Hit testing

    private func hitTest(_ annotation: Annotation, point: CGPoint, imageRect: CGRect) -> Bool {
        // Map the canvas point back into the annotation's anchor space by
        // applying the inverse of the annotation's transform
        // (translation → rotation → scale, all around the anchor center).
        let center = canvasPoint(forAnchor: annotation.anchorCenter, imageRect: imageRect)
        let dx = point.x - annotation.translation.width  - center.x
        let dy = point.y - annotation.translation.height - center.y
        let cosA = cos(-annotation.rotation)
        let sinA = sin(-annotation.rotation)
        // Inverse rotate around (0,0), then inverse scale, then re-anchor at center.
        let rx = dx * cosA - dy * sinA
        let ry = dx * sinA + dy * cosA
        let s = annotation.scale == 0 ? 1 : annotation.scale
        let unrotated = CGPoint(x: rx / s + center.x, y: ry / s + center.y)
        let anchorPoint = anchorCoords(unrotated, imageRect: imageRect)
        let bbox = annotation.anchorBoundingBox.insetBy(dx: -6, dy: -6)
        return bbox.contains(anchorPoint)
    }

    // MARK: - Draft commit

    private func commitDraft(imageRect: CGRect) {
        let localStart = anchorCoords(draftStart, imageRect: imageRect)
        let localEnd   = anchorCoords(draftEnd,   imageRect: imageRect)
        let localPoints = draftPoints.map { anchorCoords($0, imageRect: imageRect) }

        let dist = distance(draftStart, draftEnd)
        let shape: AnnotationShape
        switch activeTool {
        case .pencil:
            shape = .pencil(points: localPoints.count > 1 ? localPoints : [localStart, localEnd])
        case .circle:
            guard dist > 2 else { return }
            shape = .circle(rect: rectFromPoints(localStart, localEnd))
        case .rectangle:
            guard dist > 2 else { return }
            shape = .rectangle(rect: rectFromPoints(localStart, localEnd))
        case .arrow:
            guard dist > 2 else { return }
            shape = .arrow(from: localStart, to: localEnd)
        case .text, .select:
            return
        }
        commitAnnotation(Annotation(shape: shape, style: activeStyle))
    }

    // MARK: - Geometry helpers

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

    private func clampedPoint(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    /// Canvas-space point → anchor (image-local) coords.
    private func anchorCoords(_ point: CGPoint, imageRect: CGRect) -> CGPoint {
        CGPoint(x: point.x - imageRect.minX, y: point.y - imageRect.minY)
    }

    /// Anchor (image-local) coords → canvas-space point.
    private func canvasPoint(forAnchor point: CGPoint, imageRect: CGRect) -> CGPoint {
        CGPoint(x: point.x + imageRect.minX, y: point.y + imageRect.minY)
    }

    private func canvasRect(forAnchor rect: CGRect, imageRect: CGRect) -> CGRect {
        CGRect(x: rect.minX + imageRect.minX,
               y: rect.minY + imageRect.minY,
               width: rect.width,
               height: rect.height)
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

    /// Returns the canvas-space center of an annotation after applying its
    /// translation (rotation/scale are around this point, so neither displaces it).
    private func transformedAnchorCenterCanvas(for annotation: Annotation, imageRect: CGRect) -> CGPoint {
        let center = canvasPoint(forAnchor: annotation.anchorCenter, imageRect: imageRect)
        return CGPoint(
            x: center.x + annotation.translation.width,
            y: center.y + annotation.translation.height
        )
    }

    /// The 4 corners of the (anchor-space) bounding box transformed into
    /// canvas space — scale → rotate → translate, all around the anchor center.
    private func transformedCorners(for annotation: Annotation, imageRect: CGRect) -> [CGPoint] {
        let anchorBox = annotation.anchorBoundingBox
        let canvasBox = canvasRect(forAnchor: anchorBox, imageRect: imageRect)
        let center = canvasPoint(forAnchor: annotation.anchorCenter, imageRect: imageRect)
        let scale = annotation.scale
        let rawCorners: [CGPoint] = [
            CGPoint(x: canvasBox.minX, y: canvasBox.minY),
            CGPoint(x: canvasBox.maxX, y: canvasBox.minY),
            CGPoint(x: canvasBox.maxX, y: canvasBox.maxY),
            CGPoint(x: canvasBox.minX, y: canvasBox.maxY),
        ]
        return rawCorners.map { corner in
            // Scale around center, then rotate around center, then translate.
            let sx = (corner.x - center.x) * scale + center.x
            let sy = (corner.y - center.y) * scale + center.y
            let rotated = rotate(CGPoint(x: sx, y: sy), around: center, by: annotation.rotation)
            return CGPoint(
                x: rotated.x + annotation.translation.width,
                y: rotated.y + annotation.translation.height
            )
        }
    }

    /// Axis-aligned canvas-space bbox of the 4 transformed corners — used for
    /// move-region hit testing.
    private func transformedBoundingBox(for annotation: Annotation, imageRect: CGRect) -> CGRect {
        transformedCorners(for: annotation, imageRect: imageRect).boundingRect
    }

    private func cornerHandlePositions(for annotation: Annotation, imageRect: CGRect) -> [CGPoint] {
        transformedCorners(for: annotation, imageRect: imageRect)
    }

    private func rotate(_ point: CGPoint, around center: CGPoint, by angle: CGFloat) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let c = cos(angle), s = sin(angle)
        return CGPoint(x: dx * c - dy * s + center.x,
                       y: dx * s + dy * c + center.y)
    }

    private func rotateHandlePosition(for annotation: Annotation, imageRect: CGRect) -> CGPoint? {
        // Above the top-center of the transformed bounding box.
        let corners = transformedCorners(for: annotation, imageRect: imageRect)
        guard corners.count == 4 else { return nil }
        let topCenter = CGPoint(
            x: (corners[0].x + corners[1].x) / 2,
            y: (corners[0].y + corners[1].y) / 2
        )
        let trCenter = transformedAnchorCenterCanvas(for: annotation, imageRect: imageRect)
        let dx = topCenter.x - trCenter.x
        let dy = topCenter.y - trCenter.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else {
            return CGPoint(x: trCenter.x, y: trCenter.y - rotateHandleOffset)
        }
        let push = (len + rotateHandleOffset) / len
        return CGPoint(x: trCenter.x + dx * push, y: trCenter.y + dy * push)
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

        let localOrigin = anchorCoords(origin, imageRect: displayedRect)
        commitAnnotation(Annotation(
            shape: .text(origin: localOrigin, string: trimmed, fontSize: defaultTextFontSize),
            style: activeStyle
        ))
    }

    // MARK: - Drop handling

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    guard let nsImage = image as? NSImage else { return }
                    DispatchQueue.main.async { loadNSImage(nsImage) }
                }
                return
            }
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          url.isFileURL, url.scheme == "file",
                          let nsImage = NSImage(contentsOf: url) else { return }
                    DispatchQueue.main.async { loadNSImage(nsImage) }
                }
                return
            }
        }
    }

    private func loadNSImage(_ nsImage: NSImage) {
        guard let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        state.loadImage(cg)
    }

    // MARK: - Drawing

    private func drawAnnotation(_ annotation: Annotation,
                                in context: inout GraphicsContext,
                                imageRect: CGRect) {
        let center = canvasPoint(forAnchor: annotation.anchorCenter, imageRect: imageRect)

        // SwiftUI's GraphicsContext.draw(Text, at:) does NOT visually honor a
        // surrounding `layer.scaleBy` — the rendered glyphs stay at the
        // declared font size while everything around them scales. Handle text
        // explicitly: multiply fontSize by `annotation.scale` and reposition
        // the origin around the anchor center.
        if case .text(let originAnchor, let string, let fontSize) = annotation.shape {
            let originCanvas = canvasPoint(forAnchor: originAnchor, imageRect: imageRect)
            let scaledOrigin = CGPoint(
                x: center.x + (originCanvas.x - center.x) * annotation.scale,
                y: center.y + (originCanvas.y - center.y) * annotation.scale
            )
            context.drawLayer { layer in
                layer.translateBy(x: annotation.translation.width, y: annotation.translation.height)
                layer.translateBy(x: center.x, y: center.y)
                layer.rotate(by: Angle(radians: annotation.rotation))
                layer.translateBy(x: -center.x, y: -center.y)
                layer.draw(
                    Text(string)
                        .font(.system(size: fontSize * annotation.scale, weight: .semibold))
                        .foregroundColor(annotation.style.color),
                    at: scaledOrigin,
                    anchor: .topLeading
                )
            }
            return
        }

        // Non-text shapes scale uniformly via the layer transform.
        context.drawLayer { layer in
            layer.translateBy(x: annotation.translation.width, y: annotation.translation.height)
            layer.translateBy(x: center.x, y: center.y)
            layer.rotate(by: Angle(radians: annotation.rotation))
            layer.scaleBy(x: annotation.scale, y: annotation.scale)
            layer.translateBy(x: -center.x, y: -center.y)
            drawShape(annotation.shape, style: annotation.style, in: &layer, imageRect: imageRect)
        }
    }

    private func drawShape(_ shape: AnnotationShape,
                           style: AnnotationStyle,
                           in context: inout GraphicsContext,
                           imageRect: CGRect) {
        switch shape {
        case .pencil(let points):
            guard points.count > 1 else { return }
            var path = Path()
            path.move(to: canvasPoint(forAnchor: points[0], imageRect: imageRect))
            for pt in points.dropFirst() {
                path.addLine(to: canvasPoint(forAnchor: pt, imageRect: imageRect))
            }
            context.stroke(path,
                           with: .color(style.color),
                           style: StrokeStyle(lineWidth: style.strokeWidth,
                                              lineCap: .round,
                                              lineJoin: .round))

        case .circle(let r):
            let path = Path(ellipseIn: canvasRect(forAnchor: r, imageRect: imageRect))
            context.stroke(path, with: .color(style.color), lineWidth: style.strokeWidth)

        case .rectangle(let r):
            let path = Path(canvasRect(forAnchor: r, imageRect: imageRect))
            context.stroke(path, with: .color(style.color), lineWidth: style.strokeWidth)

        case .arrow(let from, let to):
            drawCanvasArrow(
                from: canvasPoint(forAnchor: from, imageRect: imageRect),
                to:   canvasPoint(forAnchor: to,   imageRect: imageRect),
                style: style,
                in: &context
            )

        case .text(let origin, let string, let fontSize):
            context.draw(
                Text(string)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundColor(style.color),
                at: canvasPoint(forAnchor: origin, imageRect: imageRect),
                anchor: .topLeading
            )
        }
    }

    private func drawDraft(in context: inout GraphicsContext, style: AnnotationStyle) {
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
            context.stroke(Path(ellipseIn: r),
                           with: .color(style.color.opacity(0.85)),
                           lineWidth: style.strokeWidth)

        case .rectangle:
            let r = rectFromPoints(draftStart, draftEnd)
            context.stroke(Path(r),
                           with: .color(style.color.opacity(0.85)),
                           lineWidth: style.strokeWidth)

        case .arrow:
            drawCanvasArrow(from: draftStart, to: draftEnd, style: style, in: &context, alpha: 0.85)

        case .text, .select:
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

        var shaft = Path()
        shaft.move(to: from)
        shaft.addLine(to: shaftEnd)
        context.stroke(shaft,
                       with: .color(style.color.opacity(alpha)),
                       style: StrokeStyle(lineWidth: style.strokeWidth, lineCap: .round))

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

    // MARK: - Selection overlay

    private func drawSelectionOverlay(for annotation: Annotation,
                                      in context: inout GraphicsContext,
                                      imageRect: CGRect) {
        let corners = transformedCorners(for: annotation, imageRect: imageRect)
        guard corners.count == 4 else { return }

        // Dashed bounding-box polygon connecting the 4 transformed corners.
        var bboxPath = Path()
        bboxPath.move(to: corners[0])
        for c in corners.dropFirst() { bboxPath.addLine(to: c) }
        bboxPath.closeSubpath()
        context.stroke(bboxPath,
                       with: .color(Color.accentColor),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

        // Rotate handle: above the (rotated) top edge.
        if let rotateHandle = rotateHandlePosition(for: annotation, imageRect: imageRect) {
            let topMid = CGPoint(x: (corners[0].x + corners[1].x) / 2,
                                 y: (corners[0].y + corners[1].y) / 2)
            var connector = Path()
            connector.move(to: topMid)
            connector.addLine(to: rotateHandle)
            context.stroke(connector, with: .color(Color.accentColor), lineWidth: 1)

            let handleRect = CGRect(
                x: rotateHandle.x - rotateHandleRadius,
                y: rotateHandle.y - rotateHandleRadius,
                width: rotateHandleRadius * 2,
                height: rotateHandleRadius * 2
            )
            context.fill(Path(ellipseIn: handleRect), with: .color(Color.accentColor))
            context.stroke(Path(ellipseIn: handleRect), with: .color(.white), lineWidth: 1.5)
        }

        // Corner resize handles.
        for corner in corners {
            let r = CGRect(
                x: corner.x - cornerHandleRadius,
                y: corner.y - cornerHandleRadius,
                width: cornerHandleRadius * 2,
                height: cornerHandleRadius * 2
            )
            context.fill(Path(ellipseIn: r), with: .color(Color.accentColor))
            context.stroke(Path(ellipseIn: r), with: .color(.white), lineWidth: 1.2)
        }
    }
}

// Local helper — array of CGPoint bounding rect is defined in Annotation.swift,
// but the canvas also needs it on `[CGPoint]` produced by transformedBoundingBox.
// (Same extension — already public via Annotation.swift.)
