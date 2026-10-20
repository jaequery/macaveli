// Stand-ins for the app types MouseTracker.swift touches, so the real file can
// be compiled and driven headlessly. `NSEvent` deliberately shadows AppKit's:
// it records every global monitor so the harness can count live ones and
// "deliver" a mouse event to all of them, the way the OS would.
import Cocoa

final class NSEvent {
    typealias EventTypeMask = AppKit.NSEvent.EventTypeMask

    static var mouseLocation = NSPoint(x: 500, y: 500)
    private static var nextMonitorId = 0
    private(set) static var monitors: [Int: (NSEvent) -> Void] = [:]

    static func addGlobalMonitorForEvents(matching mask: EventTypeMask, handler: @escaping (NSEvent) -> Void) -> Any? {
        nextMonitorId += 1
        monitors[nextMonitorId] = handler
        return nextMonitorId
    }

    static func removeMonitor(_ monitor: Any) {
        if let id = monitor as? Int { monitors[id] = nil }
    }

    /// Simulate one mouse event reaching every registered global monitor.
    static func deliverMouseEvent() {
        mouseLocation.x += 1
        for handler in monitors.values { handler(NSEvent()) }
    }
}

enum MouseButton: String { case none, left, right }

enum PreferenceKey: String { case focusOnApp, useQuadrants }

enum PreferencesManager {
    static func loadBool(for key: PreferenceKey) -> Bool { false }
}

var IGNORE_APP_BUNDLE_ID: [String] = []

struct WindowBounds {
    let topLeft: NSPoint
    let topRight: NSPoint
    let bottomLeft: NSPoint
    let bottomRight: NSPoint
}

enum WindowManager {
    /// nil = cursor over the desktop / nothing targetable.
    static var currentWindow: AXUIElement?
    static var axWrites = 0

    static func getCurrentWindow() -> AXUIElement? { currentWindow }
    static func getNSApplication(from element: AXUIElement) -> NSRunningApplication? { nil }
    static func getPosition(window: AXUIElement) -> NSPoint? { NSPoint(x: 100, y: 100) }
    static func getSize(window: AXUIElement) -> NSSize? { NSSize(width: 800, height: 600) }
    static func focus(window: AXUIElement) {}
    static func move(window: AXUIElement, to point: NSPoint) { axWrites += 1 }
    static func resize(window: AXUIElement, to newSize: CGSize, from origin: NSPoint) { axWrites += 1 }
    static func getWindowBounds(windowLocation: NSPoint, windowSize: CGSize) -> WindowBounds {
        WindowBounds(topLeft: windowLocation, topRight: windowLocation, bottomLeft: windowLocation, bottomRight: windowLocation)
    }
}
