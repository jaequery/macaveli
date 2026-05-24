import ShortcutRecorder
import AppKit
import LaunchAtLogin

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!
    var shortcutMonitor: GlobalShortcutMonitor?

    override init() {
        super.init()
        AppDelegate.shared = self
        self.shortcutMonitor = GlobalShortcutMonitor()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Reset enhanced-AX flags on every running app. Earlier builds wrote
        // these flags = true while trying to support Chromium/Electron, and the
        // flags persist for the lifetime of the target process. If we don't
        // clear them, dragged windows animate every position write and
        // maximize/center grow incrementally instead of snapping.
        WindowManager.cleanupResidualAccessibilityFlags()

        // Enable Launch at Login on first run only. Re-applying every launch
        // would prevent the user from turning it off.
        let didApplyKey = "didApplyLaunchAtLoginDefault"
        if !UserDefaults.standard.bool(forKey: didApplyKey) {
            LaunchAtLogin.isEnabled = true
            UserDefaults.standard.set(true, forKey: didApplyKey)
        }

        let _ = ShortcutsManager.shared // immediately register shortcuts so we won't wait for the UI
        let _ = PasteManager.shared // start clipboard monitor before the first hotkey press
        PasteWindowController.register() // wire PasteManager's panel-host factory
        // F5: Notification auth is requested lazily inside startRecording() via
        // ensureNotificationAuth(), so window-management-only users are not prompted at launch.
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        UserDefaults.standard.set(true, forKey: "showMenuBarIcon")
        return true
    }
}
