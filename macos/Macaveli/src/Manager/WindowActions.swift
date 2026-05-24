import Cocoa
import Accessibility

class WindowActions {
    static func maximize() {
        guard let window = getFocusedWindow(),
              let screen = screen(for: window) else { return }
        apply(frameInScreenCoords: screen.visibleFrame, to: window)
    }

    /// Centers the focused window on its current screen and resizes it to 60%
    /// of the screen's visible frame (excludes the menu bar and Dock).
    static func center() {
        guard let window = getFocusedWindow(),
              let screen = screen(for: window) else { return }

        let visible = screen.visibleFrame
        let ratio: CGFloat = 0.6
        let width = visible.width * ratio
        let height = visible.height * ratio
        let origin = NSPoint(
            x: visible.origin.x + (visible.width - width) / 2,
            y: visible.origin.y + (visible.height - height) / 2
        )
        let target = NSRect(origin: origin, size: NSSize(width: width, height: height))
        apply(frameInScreenCoords: target, to: window)
    }

    static func leftHalf() {
        snapHalf(side: .left)
    }

    static func rightHalf() {
        snapHalf(side: .right)
    }

    private enum HorizontalSide { case left, right }

    private static func snapHalf(side: HorizontalSide) {
        guard let window = getFocusedWindow(),
              let screen = screen(for: window) else { return }

        let visible = screen.visibleFrame
        let width = visible.width / 2
        let x = side == .left ? visible.origin.x : visible.origin.x + width
        let target = NSRect(x: x, y: visible.origin.y, width: width, height: visible.height)
        apply(frameInScreenCoords: target, to: window)
    }

    private static func apply(frameInScreenCoords frame: NSRect, to window: AXUIElement) {
        // NSScreen frames are in bottom-left origin; AX positions use top-left origin
        // measured from the top of the primary display. Convert before applying.
        let topLeftAX = WindowManager.convertYCoordinateBecauseTheAreTwoFuckingCoordinateSystems(
            point: NSPoint(x: frame.origin.x, y: frame.origin.y + frame.height)
        )
        WindowManager.resize(window: window, to: frame.size, from: topLeftAX)
    }

    private static func getFocusedWindow() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppRef) == .success,
              let focusedApp = focusedAppRef else { return nil }

        if let app = WindowManager.getNSApplication(from: focusedApp as! AXUIElement),
           let bundleId = app.bundleIdentifier,
           IGNORE_APP_BUNDLE_ID.contains(bundleId) {
            return nil
        }

        var focusedWindowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef) == .success,
              let window = focusedWindowRef else { return nil }
        return (window as! AXUIElement)
    }

    private static func screen(for window: AXUIElement) -> NSScreen? {
        guard let positionTopLeft = WindowManager.getPosition(window: window),
              let size = WindowManager.getSize(window: window) else {
            return NSScreen.main
        }

        // Convert AX top-left origin to a bottom-left frame so we can intersect with NSScreen frames
        let bottomLeftY = CGDisplayBounds(CGMainDisplayID()).height - positionTopLeft.y - size.height
        let windowRect = NSRect(x: positionTopLeft.x, y: bottomLeftY, width: size.width, height: size.height)

        var bestScreen: NSScreen?
        var bestOverlap: CGFloat = -1
        for screen in NSScreen.screens {
            let overlap = screen.frame.intersection(windowRect)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > bestOverlap {
                bestOverlap = area
                bestScreen = screen
            }
        }
        return bestScreen ?? NSScreen.main
    }
}
