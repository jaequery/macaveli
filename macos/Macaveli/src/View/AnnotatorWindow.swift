import AppKit
import SwiftUI

/// Factory that creates a configured `NSWindow` hosting the annotator UI.
///
/// The window is:
/// - Titled, closable, resizable, miniaturizable.
/// - Non-restorable (does not persist across relaunches).
/// - Sized to the image with min 640×440 and max 90% of the main screen.
/// - `isReleasedWhenClosed = false` so the hosting view is not torn down
///   before the delegate can clean up.
enum AnnotatorWindow {

    static func makeWindow(rootView: AnnotatorView) -> NSWindow {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        let defaultWidth  = min(max(screenFrame.width  * 0.75, 760), screenFrame.width  * 0.9)
        let defaultHeight = min(max(screenFrame.height * 0.75, 460), screenFrame.height * 0.9)
        let contentRect = CGRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight)

        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Annotate"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.managed, .fullScreenAuxiliary]
        // Prevent state restoration.
        window.isRestorable = false

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = CGRect(origin: .zero, size: contentRect.size)
        window.contentView = hostingView
        window.minSize = CGSize(width: 760, height: 460)

        let maxW = screenFrame.width  * 0.9
        let maxH = screenFrame.height * 0.9
        window.maxSize = CGSize(width: maxW, height: maxH)

        return window
    }
}
