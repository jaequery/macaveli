import SwiftUI

// MARK: - Tool selection

enum AnnotationTool: String, CaseIterable, Identifiable {
    case select, pencil, circle, rectangle, arrow, text
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .select:    return "Select"
        case .pencil:    return "Pencil"
        case .circle:    return "Circle"
        case .rectangle: return "Rectangle"
        case .arrow:     return "Arrow"
        case .text:      return "Text"
        }
    }
}

// MARK: - Style

/// Stroke / fill style shared by all annotation types.
/// Coordinates are stored in the canvas's logical (top-left origin)
/// coordinate space, matching the displayed image bounds.  The exporter
/// is responsible for scaling to pixel resolution.
struct AnnotationStyle: Equatable {
    var color: Color
    /// Stroke width for shapes (pencil / circle / rectangle / arrow).
    /// Clamped to 1…12 pt in logical coordinates.
    var strokeWidth: CGFloat
    /// Font size for new text annotations, in logical pt. Clamped to 8…72.
    /// Independent of `strokeWidth` — the toolbar swaps which value the
    /// size slider binds to based on the active tool.
    var fontSize: CGFloat

    init(color: Color, strokeWidth: CGFloat, fontSize: CGFloat = 16) {
        self.color = color
        self.strokeWidth = min(max(strokeWidth, 1), 12)
        self.fontSize = min(max(fontSize, 8), 72)
    }
}

// MARK: - Color palette

extension AnnotationStyle {
    static let paletteColors: [Color] = [
        .annotationRed,
        .annotationOrange,
        .annotationYellow,
        .annotationGreen,
        .annotationBlue,
        .annotationBlack,
        .annotationWhite,
    ]

    static let defaultStyle = AnnotationStyle(color: .annotationRed, strokeWidth: 8)
}

extension Color {
    static let annotationRed    = Color(red: 0.95, green: 0.20, blue: 0.20)
    static let annotationOrange = Color(red: 0.97, green: 0.55, blue: 0.15)
    static let annotationYellow = Color(red: 0.97, green: 0.85, blue: 0.10)
    static let annotationGreen  = Color(red: 0.20, green: 0.80, blue: 0.35)
    static let annotationBlue   = Color(red: 0.20, green: 0.50, blue: 0.95)
    static let annotationBlack  = Color(red: 0.05, green: 0.05, blue: 0.05)
    static let annotationWhite  = Color(red: 0.96, green: 0.96, blue: 0.96)
}

// MARK: - Annotation shape

/// The raw geometry of an annotation in its *anchor* coordinate space —
/// no rotation or translation applied. The owning `Annotation` carries a
/// transform that is applied at render and export time.
enum AnnotationShape: Equatable {
    case pencil(points: [CGPoint])
    case circle(rect: CGRect)
    case rectangle(rect: CGRect)
    case arrow(from: CGPoint, to: CGPoint)
    case text(origin: CGPoint, string: String, fontSize: CGFloat)
}

// MARK: - Annotation

/// One placed annotation. Anchor coordinates live in the canvas's logical
/// (top-left origin) coordinate space, matching the displayed image rect.
/// `translation` and `rotation` are layered on top at render and export
/// time, around the shape's center.
struct Annotation: Identifiable, Equatable {
    let id: UUID
    var shape: AnnotationShape
    var style: AnnotationStyle
    /// Additional offset from the shape's anchor coordinates, in logical pt.
    var translation: CGSize = .zero
    /// Rotation around the shape's geometric center, in radians.
    var rotation: CGFloat = 0
    /// Uniform scale around the shape's geometric center. 1.0 = original size.
    /// Clamped to [0.1, 10.0] at mutation sites.
    var scale: CGFloat = 1.0

    init(id: UUID = UUID(),
         shape: AnnotationShape,
         style: AnnotationStyle,
         translation: CGSize = .zero,
         rotation: CGFloat = 0,
         scale: CGFloat = 1.0) {
        self.id = id
        self.shape = shape
        self.style = style
        self.translation = translation
        self.rotation = rotation
        self.scale = scale
    }

    /// The geometric center (in anchor coords, pre-translation) that
    /// rotation pivots around.
    var anchorCenter: CGPoint {
        switch shape {
        case .pencil(let points):
            return points.boundingRect.center
        case .circle(let r), .rectangle(let r):
            return CGPoint(x: r.midX, y: r.midY)
        case .arrow(let from, let to):
            return CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        case .text(let origin, let string, let fontSize):
            let size = string.estimatedTextSize(fontSize: fontSize)
            return CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        }
    }

    /// The axis-aligned bounding box in anchor coords (pre-transform).
    var anchorBoundingBox: CGRect {
        switch shape {
        case .pencil(let points):
            return points.boundingRect.insetBy(dx: -style.strokeWidth, dy: -style.strokeWidth)
        case .circle(let r), .rectangle(let r):
            return r.insetBy(dx: -style.strokeWidth / 2, dy: -style.strokeWidth / 2)
        case .arrow(let from, let to):
            let minX = min(from.x, to.x), maxX = max(from.x, to.x)
            let minY = min(from.y, to.y), maxY = max(from.y, to.y)
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                .insetBy(dx: -style.strokeWidth, dy: -style.strokeWidth)
        case .text(let origin, let string, let fontSize):
            let size = string.estimatedTextSize(fontSize: fontSize)
            return CGRect(origin: origin, size: size)
        }
    }
}

// MARK: - Geometry helpers

extension Array where Element == CGPoint {
    var boundingRect: CGRect {
        guard let first = first else { return .zero }
        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y
        for p in dropFirst() {
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

extension String {
    /// Rough text size estimate used for bounding boxes / hit testing.
    /// Mirrors the system-font rendering used by both the live canvas and
    /// the CGContext export path.
    func estimatedTextSize(fontSize: CGFloat) -> CGSize {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        return (self as NSString).size(withAttributes: attrs)
    }
}
