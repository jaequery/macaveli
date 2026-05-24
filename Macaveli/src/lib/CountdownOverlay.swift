import AppKit
import SwiftUI

/// Floating countdown overlay shown before a recording begins. Mirrors the
/// pattern used by Screen Studio / QuickTime — gives the user a moment to
/// focus the window they want captured before frames start hitting disk.
///
/// The window is borderless, transparent, click-through (`ignoresMouseEvents`),
/// and lives at `.screenSaver` level so it floats above app windows. It's also
/// owned by Macaveli's own bundle, so SCContentFilter's `excludingWindows`
/// pass already keeps it out of the recording.
final class CountdownOverlay {
    static let shared = CountdownOverlay()

    private var window: NSPanel?
    private var hostingView: NSHostingView<CountdownOverlayView>?
    private var ticker: DispatchSourceTimer?
    private var remaining: Int = 0
    private var onComplete: (() -> Void)?
    private var cancelled = false

    private init() {}

    /// Shows the overlay and counts down from `seconds` to 0. Calls
    /// `completion` on the main thread when the counter reaches 0. If
    /// `cancel()` is called before then, `completion` is NOT fired.
    func show(seconds: Int, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.tearDown()
            self.cancelled = false
            self.remaining = max(1, seconds)
            self.onComplete = completion
            self.createWindow()
            self.update()
            self.startTicker()
        }
    }

    func cancel() {
        DispatchQueue.main.async {
            self.cancelled = true
            self.tearDown()
        }
    }

    // MARK: - Private

    private func createWindow() {
        guard let screen = NSScreen.main else { return }
        let size: CGFloat = 220
        let rect = NSRect(
            x: screen.visibleFrame.midX - size / 2,
            y: screen.visibleFrame.midY - size / 2,
            width: size,
            height: size
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

        let host = NSHostingView(rootView: CountdownOverlayView(number: remaining))
        host.frame = NSRect(origin: .zero, size: rect.size)
        panel.contentView = host

        panel.orderFrontRegardless()

        self.window = panel
        self.hostingView = host
    }

    private func startTicker() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.remaining -= 1
            if self.remaining <= 0 {
                self.fire()
            } else {
                self.update()
            }
        }
        timer.resume()
        ticker = timer
    }

    private func update() {
        hostingView?.rootView = CountdownOverlayView(number: remaining)
    }

    private func fire() {
        let completion = onComplete
        tearDown()
        if !cancelled { completion?() }
    }

    private func tearDown() {
        ticker?.cancel()
        ticker = nil
        window?.orderOut(nil)
        window = nil
        hostingView = nil
        onComplete = nil
    }
}

private struct CountdownOverlayView: View {
    let number: Int
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Frosted/glass disc backdrop
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 6)

            // Accent ring — soft brand presence
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .padding(6)

            Text("\(number)")
                .font(.system(size: 110, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .scaleEffect(pulse ? 1.0 : 0.85)
                .opacity(pulse ? 1.0 : 0.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: number)
        }
        .frame(width: 220, height: 220)
        .onAppear { pulse = true }
        .onChange(of: number) { _ in
            // Quick re-bump so each new digit animates in.
            pulse = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                pulse = true
            }
        }
    }
}
