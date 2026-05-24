import AVFoundation
import Cocoa
import ScreenCaptureKit

enum Preference {
    case accessibility
    case inputMonitoring
    case screenRecording
    case microphone
}

class PermissionsManager {
//    static var eventMonitor: Any?
//    
//    static func setupFakeMonitoring() {
//        let eventMask = NSEvent.EventTypeMask.keyDown
//        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask, handler: { event in
//            // Handle the global key press event
//            print("Global key press detected: \(event.keyCode)")
//        })
//    }
//    
//    static func hasInputMonitoringPermission() -> Bool {
//        setupFakeMonitoring()
//        
//        if let _ = eventMonitor {
//            // Successfully created an event monitor
//            // Remove the event monitor as it's no longer needed for the check
//            if let monitor = eventMonitor {
//                NSEvent.removeMonitor(monitor)
//                eventMonitor = nil
//            }
//            print("hasInputMonitoringPermission true")
//            return true
//        } else {
//            // Failed to create an event monitor, likely due to lack of permissions
//            print("hasInputMonitoringPermission false")
//            return false
//        }
//    }
    
    static func hasAccessibilityPermission() -> Bool {
        // Check if the app has accessibility permissions
        // Note: This is a simplified check, and more robust methods may be needed
        let checkOptionPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [checkOptionPrompt: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    static func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    private static let screenRecordingPreviouslyRequestedKey = "screenRecordingPermissionPreviouslyRequested"

    static func requestScreenRecordingPermission(completion: @escaping () -> Void = {}) {
        // Force TCC to register Macaveli for screen recording so it appears
        // in System Settings → Privacy & Security → Screen Recording. The
        // app has to *actually invoke* a screen-capture API for that to
        // happen — CGRequestScreenCaptureAccess alone is not enough on
        // recent macOS. SCShareableContent.current throws when permission
        // is denied, but TCC registers the bundle BEFORE the throw, which
        // is the side effect we need.
        let defaults = UserDefaults.standard
        let isFirstRequest = !defaults.bool(forKey: screenRecordingPreviouslyRequestedKey)
        defaults.set(true, forKey: screenRecordingPreviouslyRequestedKey)

        _ = CGRequestScreenCaptureAccess()
        if #available(macOS 12.3, *) {
            Task { @MainActor in
                _ = try? await SCShareableContent.current
                // On the first request macOS shows its own TCC alert with
                // an "Open System Settings" button. Opening Settings
                // ourselves activates the Settings window on top of that
                // alert and hides it. On subsequent requests no alert will
                // appear, so the caller's completion is the only way the
                // user reaches the toggle.
                if !isFirstRequest {
                    completion()
                }
            }
        } else if !isFirstRequest {
            completion()
        }
    }

    static func hasMicrophonePermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }

    static func openPreferences(at type: Preference) {
        switch type {
        case .accessibility:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        case .inputMonitoring:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                NSWorkspace.shared.open(url)
            }
        case .screenRecording:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        case .microphone:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
