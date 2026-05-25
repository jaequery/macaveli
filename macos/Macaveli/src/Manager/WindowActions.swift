import Cocoa
import Accessibility

class WindowActions {
    static func maximize() {
        guard let focused = getFocused(),
              let screen = screen(for: focused.window) else { return }
        apply(frameInScreenCoords: screen.visibleFrame, to: focused)
    }

    /// Centers the focused window on its current screen and resizes it to 60%
    /// of the screen's visible frame (excludes the menu bar and Dock).
    static func center() {
        guard let focused = getFocused(),
              let screen = screen(for: focused.window) else { return }

        let visible = screen.visibleFrame
        let ratio: CGFloat = 0.6
        let width = visible.width * ratio
        let height = visible.height * ratio
        let origin = NSPoint(
            x: visible.origin.x + (visible.width - width) / 2,
            y: visible.origin.y + (visible.height - height) / 2
        )
        let target = NSRect(origin: origin, size: NSSize(width: width, height: height))
        apply(frameInScreenCoords: target, to: focused)
    }

    static func leftHalf() {
        snapHalf(side: .left)
    }

    static func rightHalf() {
        snapHalf(side: .right)
    }

    private enum HorizontalSide { case left, right }

    private static func snapHalf(side: HorizontalSide) {
        guard let focused = getFocused(),
              let screen = screen(for: focused.window) else { return }

        let visible = screen.visibleFrame
        let width = visible.width / 2
        let x = side == .left ? visible.origin.x : visible.origin.x + width
        let target = NSRect(x: x, y: visible.origin.y, width: width, height: visible.height)
        apply(frameInScreenCoords: target, to: focused)
    }

    private static func apply(frameInScreenCoords frame: NSRect, to focused: (app: AXUIElement, window: AXUIElement)) {
        let window = focused.window
        // NSScreen frames are in bottom-left origin; AX positions use top-left origin
        // measured from the top of the primary display. Convert before applying.
        let topLeftAX = WindowManager.convertYCoordinateBecauseTheAreTwoFuckingCoordinateSystems(
            point: NSPoint(x: frame.origin.x, y: frame.origin.y + frame.height)
        )

        // Electron/Catalyst apps (Slack, VS Code, …) ship with AXEnhancedUserInterface
        // on, which makes macOS animate AX frame changes and silently drop the values
        // we set. Disable it for the duration of the change, then restore it.
        let enhancedKey = "AXEnhancedUserInterface" as CFString
        var enhancedRef: CFTypeRef?
        let wasEnhanced = AXUIElementCopyAttributeValue(focused.app, enhancedKey, &enhancedRef) == .success
            && (enhancedRef as? Bool == true)
        if wasEnhanced {
            AXUIElementSetAttributeValue(focused.app, enhancedKey, kCFBooleanFalse)
        }

        // Size → position → size. A single move-then-resize gets clamped by stubborn
        // apps: moving a still-large window to an inset origin is pinned on-screen,
        // and growing before there's room is rejected. Shrinking first makes room to
        // move, and the final size pass fixes the grow case.
        WindowManager.setSize(window: window, to: frame.size)
        WindowManager.move(window: window, to: topLeftAX)
        WindowManager.setSize(window: window, to: frame.size)

        if wasEnhanced {
            AXUIElementSetAttributeValue(focused.app, enhancedKey, kCFBooleanTrue)
        }
    }

    private static func getFocused() -> (app: AXUIElement, window: AXUIElement)? {
        // Resolve the frontmost app via NSWorkspace (reads from the window server)
        // rather than the system-wide AX element's kAXFocusedApplicationAttribute,
        // which has to AX-message the target app and times out for apps with a busy
        // main thread (Slack/Electron) — returning an error and dropping the action.
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        if let bundleId = frontApp.bundleIdentifier, IGNORE_APP_BUNDLE_ID.contains(bundleId) {
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        // Give a stubborn app a little longer to answer before we give up.
        AXUIElementSetMessagingTimeout(appElement, 1.0)

        var focusedWindowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef) == .success,
              let window = focusedWindowRef else {
            return nil
        }
        return (appElement, (window as! AXUIElement))
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
