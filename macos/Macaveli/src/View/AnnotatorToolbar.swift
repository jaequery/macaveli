import SwiftUI
import UniformTypeIdentifiers

// MARK: - AnnotatorToolbar

/// Horizontal toolbar strip rendered above the annotation canvas.
/// Clusters (left → right): tool picker | color swatches | stroke width | undo/redo | copy/close.
struct AnnotatorToolbar: View {
    @Binding var tool: AnnotationTool
    @Binding var style: AnnotationStyle
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Cluster 1: Tool picker
            ToolPickerCluster(tool: $tool)

            toolbarDivider()

            // Cluster 2: Color swatches
            ColorSwatchCluster(selectedColor: $style.color)

            toolbarDivider()

            // Cluster 3: Stroke width
            StrokeWidthCluster(strokeWidth: $style.strokeWidth)

            toolbarDivider()

            // Cluster 4: Undo / redo
            UndoRedoCluster(
                canUndo: canUndo,
                canRedo: canRedo,
                onUndo: onUndo,
                onRedo: onRedo
            )

            Spacer(minLength: 8)

            // Cluster 5: Copy / close (right-aligned)
            ActionCluster(onCopy: onCopy, onClose: onClose)
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Divider()
                .opacity(0.5),
            alignment: .bottom
        )
    }

    private func toolbarDivider() -> some View {
        Divider()
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
    }
}

// MARK: - Tool picker cluster

private struct ToolPickerCluster: View {
    @Binding var tool: AnnotationTool

    private let tools: [(AnnotationTool, String, String)] = [
        (.pencil,    "pencil.tip",         "Pencil (1)"),
        (.circle,    "circle",             "Circle (2)"),
        (.rectangle, "rectangle",          "Rectangle (3)"),
        (.arrow,     "arrow.up.right",     "Arrow (4)"),
        (.text,      "textformat",         "Text (5)"),
    ]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(tools, id: \.0) { (annotationTool, symbol, label) in
                ToolButton(
                    symbol: symbol,
                    label: label,
                    isSelected: tool == annotationTool,
                    action: { tool = annotationTool }
                )
            }
        }
    }
}

private struct ToolButton: View {
    let symbol: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            isSelected
                                ? Color.accentColor.opacity(0.18)
                                : (isHovering ? Color.primary.opacity(0.08) : Color.clear)
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Color swatch cluster

private struct ColorSwatchCluster: View {
    @Binding var selectedColor: Color

    private let swatches: [(Color, String)] = [
        (.annotationRed,    "Red"),
        (.annotationOrange, "Orange"),
        (.annotationYellow, "Yellow"),
        (.annotationGreen,  "Green"),
        (.annotationBlue,   "Blue"),
        (.annotationBlack,  "Black"),
        (.annotationWhite,  "White"),
    ]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(swatches, id: \.1) { (color, name) in
                ColorSwatch(
                    color: color,
                    name: name,
                    isSelected: selectedColor == color,
                    action: { selectedColor = color }
                )
            }
        }
    }
}

private struct ColorSwatch: View {
    let color: Color
    let name: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    /// White and yellow need a darker border to remain visible on light backgrounds.
    private var borderColor: Color {
        switch name {
        case "White":  return Color.primary.opacity(0.22)
        case "Yellow": return Color.primary.opacity(0.18)
        default:       return Color.primary.opacity(0.08)
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Base swatch
                Circle()
                    .fill(isHovering ? color.opacity(0.75) : color)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: 0.75)
                    )

                // Selected ring — 2 pt outside the swatch
                if isSelected {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(name)
        .accessibilityLabel(name + " color swatch" + (isSelected ? ", selected" : ""))
    }
}

// MARK: - Stroke width cluster

private struct StrokeWidthCluster: View {
    @Binding var strokeWidth: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Slider(value: $strokeWidth, in: 1...12, step: 1)
                .frame(width: 90)
                .controlSize(.mini)
                .accessibilityLabel("Stroke width")
                .accessibilityValue("\(Int(strokeWidth)) points")
            Text("\(Int(strokeWidth)) pt")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 28, alignment: .leading)
        }
    }
}

// MARK: - Undo / redo cluster

private struct UndoRedoCluster: View {
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            IconActionButton(
                symbol: "arrow.uturn.backward",
                label: "Undo (⌘Z)",
                isEnabled: canUndo,
                action: onUndo
            )
            IconActionButton(
                symbol: "arrow.uturn.forward",
                label: "Redo (⇧⌘Z)",
                isEnabled: canRedo,
                action: onRedo
            )
        }
    }
}

private struct IconActionButton: View {
    let symbol: String
    let label: String
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 24, height: 24)
                .foregroundStyle(isEnabled ? Color.primary.opacity(0.8) : Color.secondary.opacity(0.35))
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovering && isEnabled ? Color.primary.opacity(0.08) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { isHovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Action cluster (Copy / Close)

private struct ActionCluster: View {
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Copy — default/primary button
            Button(action: onCopy) {
                HStack(spacing: 4) {
                    Text("Copy")
                        .font(.system(size: 12, weight: .semibold))
                    Text("⌘↩")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .opacity(0.7)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor)
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Copy annotated image to clipboard (⌘↩)")
            .accessibilityLabel("Copy annotated image to clipboard")

            // Close — quiet secondary button
            Button(action: onClose) {
                HStack(spacing: 4) {
                    Text("Close")
                        .font(.system(size: 12))
                    Text("⎋")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .opacity(0.6)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(Color.primary.opacity(0.75))
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("Close without copying (⎋)")
            .accessibilityLabel("Close without copying")
        }
    }
}

// MARK: - Preview

private struct AnnotatorToolbarPreviewWrapper: View {
    @State var tool: AnnotationTool = .pencil
    @State var style = AnnotationStyle.defaultStyle

    var body: some View {
        AnnotatorToolbar(
            tool: $tool,
            style: $style,
            canUndo: true,
            canRedo: false,
            onUndo: {},
            onRedo: {},
            onCopy: {},
            onClose: {}
        )
        .frame(width: 760)
    }
}

#Preview("AnnotatorToolbar") {
    AnnotatorToolbarPreviewWrapper()
}
