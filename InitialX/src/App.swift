import SwiftUI
import AppKit
import Sparkle

@main
struct InitialXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("showMenuBarIcon") var showMenuBarIcon = true
    @StateObject private var screenRecorder = ScreenRecorder.shared

    var body: some Scene {
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            AppView()
        } label: {
            if screenRecorder.isRecording {
                Image("MenuBarIconRecording")
                    .renderingMode(.original)
                    .resizable()
            } else {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
            }
        }
        .menuBarExtraStyle(.window)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 400, height: 400)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckUpdatesButton()
            }
        }
    }
}
