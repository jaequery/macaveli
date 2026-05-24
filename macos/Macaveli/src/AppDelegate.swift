import ShortcutRecorder
import AppKit

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

        let _ = ShortcutsManager.shared // immediately register shortcuts so we won't wait for the UI
        let _ = PasteManager.shared // start clipboard monitor before the first hotkey press
        // F5: Notification auth is requested lazily inside startRecording() via
        // ensureNotificationAuth(), so window-management-only users are not prompted at launch.
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        UserDefaults.standard.set(true, forKey: "showMenuBarIcon")
        return true
    }
}
