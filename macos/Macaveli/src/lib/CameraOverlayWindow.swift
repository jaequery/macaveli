import AppKit
import AVFoundation
import os

private let coLog = Logger(subsystem: "com.jaequery.Macaveli", category: "camera-overlay")

/// Floating, draggable camera bubble shown during a recording. It is the
/// WYSIWYG positioning handle: the user drags it to place the camera, and the
/// recorder composites its own copy of the same camera frame at the matching
/// spot on the recorded canvas (this panel is a Macaveli window, so SCStream's
/// `excludingWindows` / `excludedBundleIDs` pass keeps it out of the capture —
/// no double image).
///
/// Position is persisted as a normalized center (top-left origin) via
/// `CameraOverlayDefaults`, so it survives across sessions and maps cleanly
/// into the recorded video's pixel space.
final class CameraOverlayWindow {
    static let shared = CameraOverlayWindow()

    private var panel: NSPanel?
    private var bubble: CameraBubbleView?

    private init() {}

    /// Shows the bubble at the persisted (or default bottom-right) position.
    /// Idempotent. The caller is responsible for starting `CameraManager`.
    func show() {
        DispatchQueue.main.async {
            guard self.panel == nil else {
                self.panel?.orderFrontRegardless()
                return
            }
            guard let screen = NSScreen.main else { return }

            let diameter = Self.diameter(on: screen)
            let origin = Self.origin(for: CameraOverlayDefaults.center(), diameter: diameter, on: screen)
            let rect = NSRect(origin: origin, size: CGSize(width: diameter, height: diameter))

            let panel = NSPanel(
                contentRect: rect,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isReleasedWhenClosed = false

            let bubble = CameraBubbleView(frame: NSRect(origin: .zero, size: rect.size))
            bubble.onMoved = { [weak self] in self?.persistCenter() }
            panel.contentView = bubble
            panel.orderFrontRegardless()

            self.panel = panel
            self.bubble = bubble
            coLog.log("camera overlay shown diameter=\(Int(diameter), privacy: .public)")
        }
    }

    /// Hides and tears down the bubble.
    func hide() {
        DispatchQueue.main.async {
            self.panel?.orderOut(nil)
            self.bubble?.detachPreview()
            self.bubble = nil
            self.panel = nil
        }
    }

    // MARK: - Geometry

    private static func diameter(on screen: NSScreen) -> CGFloat {
        let shortest = min(screen.frame.width, screen.frame.height)
        return (shortest * CameraOverlayDefaults.diameterFraction).rounded()
    }

    /// Converts a normalized center (top-left origin) into the window's
    /// bottom-left origin in global screen coordinates.
    private static func origin(for center: (x: Double, y: Double), diameter: CGFloat, on screen: NSScreen) -> CGPoint {
        let f = screen.frame
        let cxTop = CGFloat(center.x) * f.width
        let cyTop = CGFloat(center.y) * f.height
        let globalCenterX = f.minX + cxTop
        let globalCenterY = f.minY + (f.height - cyTop) // flip top-left → bottom-left
        return CGPoint(x: globalCenterX - diameter / 2, y: globalCenterY - diameter / 2)
    }

    /// Persists the bubble's current center as a normalized top-left fraction
    /// of the screen it sits on.
    private func persistCenter() {
        guard let panel else { return }
        let frame = panel.frame
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        guard let screen else { return }
        let f = screen.frame
        let cxTop = center.x - f.minX
        let cyTop = f.height - (center.y - f.minY) // bottom-left → top-left
        CameraOverlayDefaults.setCenter(x: Double(cxTop / f.width), y: Double(cyTop / f.height))
    }
}

/// Circular, mirrored live-camera view that drags its host window and reports
/// each move so the position can be persisted.
private final class CameraBubbleView: NSView {
    var onMoved: (() -> Void)?

    private let previewLayer = CameraManager.shared.previewLayer
    private var dragOffset: CGPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        guard let host = layer else { return }
        host.cornerRadius = frameRect.width / 2
        host.masksToBounds = true
        host.borderWidth = 3
        host.borderColor = NSColor.white.withAlphaComponent(0.9).cgColor
        host.backgroundColor = NSColor.black.cgColor

        previewLayer.frame = bounds
        previewLayer.cornerRadius = frameRect.width / 2
        previewLayer.masksToBounds = true
        // Mirror like a selfie — matches the compositor's mirrored overlay.
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        host.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }

    /// Detaches the shared preview layer so it can be re-attached on the next
    /// show without AVFoundation complaining about a layer with two superlayers.
    func detachPreview() {
        previewLayer.removeFromSuperlayer()
    }

    // Borderless non-activating panels don't drag from the background reliably,
    // so move the host window by hand.
    override func mouseDown(with event: NSEvent) {
        // Offset of the cursor within the window at drag start, so the bubble
        // tracks the pointer without jumping.
        dragOffset = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let offset = dragOffset else { return }
        let mouseOnScreen = NSEvent.mouseLocation
        let newOrigin = CGPoint(x: mouseOnScreen.x - offset.x, y: mouseOnScreen.y - offset.y)
        window.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        dragOffset = nil
        onMoved?()
    }
}
