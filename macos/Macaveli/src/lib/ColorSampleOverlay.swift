import AppKit
import SwiftUI

/// Transient toast shown after the eyedropper samples a color — swatch plus
/// HEX / RGB / HSL codes. The hex is already on the clipboard when this shows.
final class ColorSampleOverlay {
    static let shared = ColorSampleOverlay()

    private var window: NSPanel?
    private var hostingView: NSHostingView<ColorSampleOverlayView>?
    private var dismissTimer: DispatchSourceTimer?

    private init() {}

    func show(_ sample: ColorSample, duration: TimeInterval = 4.0) {
        DispatchQueue.main.async {
            self.tearDown()
            self.createWindow(for: sample)
            self.startDismissTimer(duration: duration)
        }
    }

    // MARK: - Private

    private func createWindow(for sample: ColorSample) {
        guard let screen = NSScreen.main else { return }
        let width: CGFloat = 280
        let height: CGFloat = 110
        let rect = NSRect(
            x: screen.visibleFrame.midX - width / 2,
            y: screen.visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false

        let host = NSHostingView(rootView: ColorSampleOverlayView(sample: sample))
        host.frame = NSRect(origin: .zero, size: rect.size)
        panel.contentView = host
        panel.orderFrontRegardless()

        window = panel
        hostingView = host
    }

    private func startDismissTimer(duration: TimeInterval) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + duration)
        timer.setEventHandler { [weak self] in
            self?.tearDown()
        }
        timer.resume()
        dismissTimer = timer
    }

    private func tearDown() {
        dismissTimer?.cancel()
        dismissTimer = nil
        window?.orderOut(nil)
        window = nil
        hostingView = nil
    }
}

private struct ColorSampleOverlayView: View {
    let sample: ColorSample
    @State private var visible = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: sample.color))
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    codeRow(label: "HEX", value: sample.hex)
                    Text("copied")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                codeRow(label: "RGB", value: sample.rgbText)
                codeRow(label: "HSL", value: sample.hslText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 6)
        }
        .scaleEffect(visible ? 1.0 : 0.92)
        .opacity(visible ? 1.0 : 0.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: visible)
        .onAppear { visible = true }
    }

    private func codeRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}
