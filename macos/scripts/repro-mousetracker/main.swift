// Drives the real MouseTracker through the hotkey sequences from MACA-59KJM0
// and fails if a global monitor leaks or a long drag is cut off.
import Cocoa

let tracker = MouseTracker.shared
let window = AXUIElementCreateApplication(getpid())
var failures = 0

func check(_ name: String, _ ok: Bool, _ detail: String) {
    print("\(ok ? "PASS" : "FAIL")  \(name) — \(detail)")
    if !ok { failures += 1 }
}

func pump(_ seconds: TimeInterval) {
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
}

// 1. Modifier-only move hotkey held over the desktop, released, then held over
//    a window — 20 times, faster than the 4 s timer. HotkeysManager calls
//    stopTracking(for:) on every flag change, then startTracking on a match.
var maxLive = 0
for _ in 0..<20 {
    WindowManager.currentWindow = nil
    tracker.stopTracking(for: .move)
    tracker.startTracking(for: .move, button: .none)
    maxLive = max(maxLive, NSEvent.monitors.count)
    tracker.stopTracking(for: .move)

    WindowManager.currentWindow = window
    tracker.startTracking(for: .move, button: .none)
    maxLive = max(maxLive, NSEvent.monitors.count)
    tracker.stopTracking(for: .move)
}
check("desktop→window cycles x20", maxLive <= 1 && NSEvent.monitors.isEmpty,
      "max live monitors \(maxLive), live after final stop \(NSEvent.monitors.count)")

// One mouse event during a fresh drag should cause exactly one AX write.
tracker.forceStopTracking()
WindowManager.currentWindow = window
tracker.startTracking(for: .move, button: .none)
WindowManager.axWrites = 0
NSEvent.deliverMouseEvent()
check("AX writes per mouse event", WindowManager.axWrites == 1,
      "\(WindowManager.axWrites) writes for 1 event (live monitors \(NSEvent.monitors.count))")
tracker.forceStopTracking()
check("forceStopTracking clears everything", NSEvent.monitors.isEmpty,
      "live monitors after forceStop \(NSEvent.monitors.count)")

// 2. Overlapping modifier sets (move ⌃⌥, resize ⌃⌥⇧): resize starts while move
//    is still tracking, because each handler only stops its own action.
WindowManager.currentWindow = window
tracker.startTracking(for: .move, button: .none)
tracker.startTracking(for: .resize, button: .none)
let liveDuringOverlap = NSEvent.monitors.count
tracker.stopTracking(for: .resize)
check("overlapping move→resize", liveDuringOverlap <= 1 && NSEvent.monitors.isEmpty,
      "live monitors during overlap \(liveDuringOverlap), after resize stop \(NSEvent.monitors.count)")
tracker.forceStopTracking()

// 3. A continuous drag longer than the 4 s timeout keeps tracking; tracking
//    still auto-stops once the mouse has been idle for ~4 s.
WindowManager.currentWindow = window
tracker.startTracking(for: .move, button: .none)
let dragStart = Date()
while Date().timeIntervalSince(dragStart) < 5 {
    NSEvent.deliverMouseEvent()
    pump(0.1)
}
WindowManager.axWrites = 0
NSEvent.deliverMouseEvent()
check("drag > 4 s keeps tracking", WindowManager.axWrites == 1,
      "after 5 s of continuous movement: \(WindowManager.axWrites) AX write(s), live monitors \(NSEvent.monitors.count)")
pump(4.5)
check("idle 4.5 s auto-stops", NSEvent.monitors.isEmpty,
      "live monitors after 4.5 s idle \(NSEvent.monitors.count)")

print(failures == 0 ? "ALL PASS" : "\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)
