import SwiftUI

// MARK: - Tool selection

enum AnnotationTool: String, CaseIterable, Identifiable {
    case pencil, circle, rectangle, arrow, text
    var id: String { rawValue }

    var displayName: String {
        switch self {
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
    /// Clamped to 1…12 px in logical coordinates.
    var strokeWidth: CGFloat

    init(color: Color, strokeWidth: CGFloat) {
        self.color = color
        self.strokeWidth = min(max(strokeWidth, 1), 12)
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

    static let defaultStyle = AnnotationStyle(color: .annotationRed, strokeWidth: 3)
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

// MARK: - Annotation model

/// One completed annotation stored in the canvas's logical coordinate space.
/// All measurements are in points relative to the displayed image rect
/// (origin top-left).
enum Annotation: Identifiable, Equatable {
    case pencil(id: UUID, points: [CGPoint], style: AnnotationStyle)
    case circle(id: UUID, rect: CGRect, style: AnnotationStyle)
    case rectangle(id: UUID, rect: CGRect, style: AnnotationStyle)
    case arrow(id: UUID, from: CGPoint, to: CGPoint, style: AnnotationStyle)
    case text(id: UUID, origin: CGPoint, string: String, style: AnnotationStyle, fontSize: CGFloat)

    var id: UUID {
        switch self {
        case .pencil(let id, _, _):       return id
        case .circle(let id, _, _):       return id
        case .rectangle(let id, _, _):    return id
        case .arrow(let id, _, _, _):     return id
        case .text(let id, _, _, _, _):   return id
        }
    }

    var style: AnnotationStyle {
        switch self {
        case .pencil(_, _, let s):       return s
        case .circle(_, _, let s):       return s
        case .rectangle(_, _, let s):    return s
        case .arrow(_, _, _, let s):     return s
        case .text(_, _, _, let s, _):   return s
        }
    }
}
