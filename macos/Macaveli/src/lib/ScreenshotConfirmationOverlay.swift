import AppKit
import SwiftUI

/// Transient toast shown after a screenshot lands on the clipboard.
final class ScreenshotConfirmationOverlay {
    static let shared = ScreenshotConfirmationOverlay()

    private var window: NSPanel?
    private var hostingView: NSHostingView<ScreenshotConfirmationOverlayView>?
    private var dismissTimer: DispatchSourceTimer?

    private init() {}

    func show(duration: TimeInterval = 3.0) {
        DispatchQueue.main.async {
            self.tearDown()
            self.createWindow()
            self.startDismissTimer(duration: duration)
        }
    }

    // MARK: - Private

    private func createWindow() {
        guard let screen = NSScreen.main else { return }
        let width: CGFloat = 340
        let height: CGFloat = 72
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

        let host = NSHostingView(rootView: ScreenshotConfirmationOverlayView())
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

private struct ScreenshotConfirmationOverlayView: View {
    @State private var visible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("Screenshot saved to clipboard")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
}
