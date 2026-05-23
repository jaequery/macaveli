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
        let _ = ShortcutsManager.shared // immediately register shortcuts so we won't wait for the UI
        // F5: Notification auth is requested lazily inside startRecording() via
        // ensureNotificationAuth(), so window-management-only users are not prompted at launch.
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        UserDefaults.standard.set(true, forKey: "showMenuBarIcon")
        return true
    }
}
