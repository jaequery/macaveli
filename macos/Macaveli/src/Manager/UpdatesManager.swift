import AppKit
import Sparkle

class UpdatesManager {
    static var shared = UpdatesManager()
    let controller: SPUStandardUpdaterController
    let updater: SPUUpdater
    
    init() {
        self.controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.updater = controller.updater
    }
    
    func checkForUpdates() {
        // Menubar-only (LSUIElement) app: without activating first, Sparkle's
        // update window opens behind the frontmost app and the click looks
        // like it did nothing.
        NSApp.activate(ignoringOtherApps: true)
        self.updater.checkForUpdates()
    }
}
