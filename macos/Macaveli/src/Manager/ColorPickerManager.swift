import AppKit

/// A sampled screen color plus its display-ready code strings.
struct ColorSample {
    let color: NSColor
    let hex: String
    let rgbText: String
    let hslText: String

    init?(color: NSColor) {
        guard let srgb = color.usingColorSpace(.sRGB) else { return nil }
        self.color = srgb

        let r = srgb.redComponent
        let g = srgb.greenComponent
        let b = srgb.blueComponent

        let r255 = Int((r * 255).rounded())
        let g255 = Int((g * 255).rounded())
        let b255 = Int((b * 255).rounded())

        hex = String(format: "#%02X%02X%02X", r255, g255, b255)
        rgbText = "\(r255), \(g255), \(b255)"

        // RGB → HSL. Hue in degrees, saturation/lightness in percent.
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        let lightness = (maxC + minC) / 2

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        if delta > 0 {
            saturation = delta / (1 - abs(2 * lightness - 1))
            switch maxC {
            case r: hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            case g: hue = (b - r) / delta + 2
            default: hue = (r - g) / delta + 4
            }
            hue *= 60
            if hue < 0 { hue += 360 }
        }

        hslText = String(
            format: "%.0f°, %.0f%%, %.0f%%",
            hue, saturation * 100, lightness * 100
        )
    }
}

/// Runs macOS's native eyedropper (`NSColorSampler`), copies the sampled
/// color's hex code to the clipboard, and shows a toast with all its codes.
final class ColorPickerManager {
    static let shared = ColorPickerManager()

    private let sampler = NSColorSampler()
    private var isPicking = false

    private init() {}

    func pick() {
        guard !isPicking else { return }
        isPicking = true

        sampler.show { [weak self] color in
            // Selection handler arrives on the main thread; nil means the
            // user dismissed the loupe (Esc) without picking.
            self?.isPicking = false
            guard let color, let sample = ColorSample(color: color) else { return }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(sample.hex, forType: .string)

            ColorSampleOverlay.shared.show(sample)
        }
    }
}
