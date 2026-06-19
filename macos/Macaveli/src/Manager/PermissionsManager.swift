import Cocoa
import ScreenCaptureKit

enum Preference {
    case accessibility
    case inputMonitoring
    case screenRecording
}

/// Where the running app bundle physically lives. This is the crux of the
/// "I granted permission but it still says I need it" bug: macOS keys
/// Accessibility / Screen-Recording grants to the running binary's path +
/// signature. Anything other than `.applications` means a granted toggle in
/// System Settings can point at a *different* (often randomized, read-only)
/// copy than the one currently running, so the live trust check keeps
/// returning false even though the list looks correct.
enum AppLocation {
    /// Installed under /Applications (or ~/Applications) — grants persist.
    case applications
    /// Gatekeeper App Translocation: the user opened it straight from the DMG
    /// or Downloads, so macOS is running it from a randomized read-only mount.
    /// Grants made here evaporate on the next launch (new random path).
    case translocated
    /// On disk but somewhere grants won't reliably stick (Downloads, Desktop,
    /// a mounted volume, the DMG without translocation, …).
    case elsewhere

    var needsMove: Bool { self != .applications }
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

    /// Force TCC to register Macaveli for screen recording so it appears in
    /// System Settings → Privacy & Security → Screen & System Audio Recording.
    /// The app must *actually invoke* a screen-capture API for that — calling
    /// CGRequestScreenCaptureAccess alone is unreliable on recent macOS.
    /// SCShareableContent.current throws when permission is missing, but TCC
    /// registers the bundle before the throw, which is the side effect we need.
    /// `completion` always fires (after the async registration call) so the
    /// caller can open Settings — if macOS pops its own TCC alert at the same
    /// time, the user can dismiss whichever they don't need.
    static func requestScreenRecordingPermission(completion: @escaping () -> Void = {}) {
        _ = CGRequestScreenCaptureAccess()
        if #available(macOS 12.3, *) {
            Task { @MainActor in
                _ = try? await SCShareableContent.current
                completion()
            }
        } else {
            completion()
        }
    }

    // MARK: - App location (the root cause of "granted but still asks")

    // The SecTranslocate API lives in Security.framework but isn't exposed to
    // Swift (no module-map entry), so we resolve the two C functions we need by
    // symbol at runtime. dlopen'ing the framework guarantees the symbols are
    // present regardless of what the app links.
    private static let securityHandle: UnsafeMutableRawPointer? =
        dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY)

    private typealias IsTranslocatedFn = @convention(c)
        (CFURL, UnsafeMutablePointer<DarwinBoolean>?, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> DarwinBoolean
    private typealias OriginalPathFn = @convention(c)
        (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle = securityHandle, let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: type)
    }

    /// Classify where the running bundle lives so the permission prompt can
    /// explain *why* a grant didn't stick and offer the right fix.
    static func currentAppLocation() -> AppLocation {
        let url = Bundle.main.bundleURL

        // App Translocation: Gatekeeper runs downloaded-but-not-moved apps from
        // a randomized read-only path. SecTranslocateIsTranslocatedURL is the
        // authoritative check; the path heuristic is a belt-and-suspenders for
        // when the symbol can't be resolved.
        if let isTranslocatedURL = symbol("SecTranslocateIsTranslocatedURL", as: IsTranslocatedFn.self) {
            var isTranslocated = DarwinBoolean(false)
            if isTranslocatedURL(url as CFURL, &isTranslocated, nil).boolValue, isTranslocated.boolValue {
                return .translocated
            }
        }
        if url.path.contains("/AppTranslocation/") {
            return .translocated
        }

        let path = (url.path as NSString).standardizingPath
        let appDirs = FileManager.default.urls(for: .applicationDirectory, in: [.localDomainMask, .userDomainMask])
            .map { ($0.path as NSString).standardizingPath }
        if appDirs.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return .applications
        }
        return .elsewhere
    }

    /// The bundle URL the user actually keeps on disk. For a translocated app
    /// that's the original (de-randomized) location; otherwise the live URL.
    /// (Copying the translocated bundle itself also yields a valid app, so this
    /// is a best-effort nicety, not a correctness requirement.)
    private static func originalBundleURL() -> URL {
        let url = Bundle.main.bundleURL
        if let originalPath = symbol("SecTranslocateCreateOriginalPathForURL", as: OriginalPathFn.self),
           let original = originalPath(url as CFURL, nil) {
            return original.takeRetainedValue() as URL
        }
        return url
    }

    // MARK: - Recovery actions

    /// Launch a fresh copy of `url` (default: this app) and terminate the
    /// current process. A relaunch is the only thing that re-reads a freshly
    /// granted Screen-Recording permission (CGPreflightScreenCaptureAccess is
    /// cached per-process) and the simplest way to pick up a stale-TCC fix.
    static func relaunch(from url: URL? = nil) {
        let target = url ?? Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: target, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    /// Move the app into /Applications and relaunch from there so grants
    /// persist. Non-destructive: copies (never deletes the source); if a copy
    /// already exists in /Applications we relaunch *that* one rather than
    /// clobber it. Any failure falls back to revealing the app in Finder so the
    /// user can drag it manually.
    static func moveToApplicationsAndRelaunch() {
        let fm = FileManager.default
        let source = originalBundleURL()
        let appsDir = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let dest = appsDir.appendingPathComponent(source.lastPathComponent)

        // Already a copy in /Applications → just hand off to it.
        if fm.fileExists(atPath: dest.path) {
            relaunch(from: dest)
            return
        }

        do {
            try fm.copyItem(at: source, to: dest)
            relaunch(from: dest)
        } catch {
            // Couldn't copy (permissions, read-only source, …). Reveal the app
            // so the user can drag it to Applications themselves.
            NSWorkspace.shared.activateFileViewerSelecting([source])
        }
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
        }
    }
}
