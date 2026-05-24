// PasteWindow.swift
//
// NSPanel + controller that hosts the clipboard-history panel.
//
// To activate this UI, AppDelegate should call:
//     PasteWindowController.register()
// after `let _ = PasteManager.shared`.

import AppKit
import SwiftUI

// MARK: - PasteWindow (NSPanel subclass)

/// Borderless, non-activating floating panel that hosts `PasteView`.
///
/// Key policy: `becomesKeyOnlyIfNeeded = false` so the panel always accepts
/// keyboard input when shown. `hidesOnDeactivate = true` closes the panel
/// automatically when any other app becomes active.
final class PasteWindow: NSPanel {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: Factory

    /// Creates a fully-configured `PasteWindow` hosting the given root view.
    ///
    /// Size: 560 × 440, centered on the active screen at call-time.
    static func makeWindow(rootView: PasteView) -> PasteWindow {
        let panelWidth: CGFloat  = 560
        let panelHeight: CGFloat = 440

        let window = PasteWindow(
            contentRect: CGRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.level                  = .floating
        window.hidesOnDeactivate      = true
        window.becomesKeyOnlyIfNeeded = false
        window.isReleasedWhenClosed   = false
        window.isOpaque               = false
        window.backgroundColor        = .clear
        window.isMovableByWindowBackground = true
        window.collectionBehavior     = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = CGRect(origin: .zero, size: CGSize(width: panelWidth, height: panelHeight))
        window.contentView = hosting

        window.centerOnActiveScreen()
        return window
    }
}

// MARK: - Screen centering helper

private extension PasteWindow {
    func centerOnActiveScreen() {
        let screen  = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
                   ?? NSScreen.main
                   ?? NSScreen.screens.first
        guard let screen else { return }
        let sf = screen.visibleFrame
        let wf = frame
        let x = sf.midX - wf.width  / 2
        let y = sf.midY - wf.height / 2 + sf.height * 0.05  // slightly above center
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - PasteWindowController

/// Manages the lifecycle of `PasteWindow` and bridges it to `PasteManager`
/// via the `PastePanelHost` protocol.
final class PasteWindowController: NSWindowController, PastePanelHost {

    // MARK: Registration

    /// Call once from `AppDelegate.applicationDidFinishLaunching` (after
    /// `let _ = PasteManager.shared`) so the manager can lazily create this
    /// controller when the hotkey fires for the first time.
    static func register() {
        PasteManager.shared.makePanelHost = { PasteWindowController() }
    }

    // MARK: Init

    init() {
        let pasteView = PasteView()
        let panel     = PasteWindow.makeWindow(rootView: pasteView)
        super.init(window: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: PastePanelHost

    func toggle() {
        guard let w = window else { return }
        if w.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let panel = window as? PasteWindow else { return }

        // Capture the frontmost app BEFORE we steal focus.
        PasteManager.shared.recordCurrentFrontmost()

        // Re-center every time the panel is shown so it always appears on the
        // active screen, even when the user has moved it or switched displays.
        panel.centerOnActiveScreen()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
