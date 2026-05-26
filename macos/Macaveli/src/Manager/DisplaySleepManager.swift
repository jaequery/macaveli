import AppKit
import Foundation
import os.log

// MARK: - DisplaySleepManager

/// Owns the "keep external display on when the lid is closed" preference.
///
/// macOS turns off an external display when the lid closes unless full
/// clamshell-mode conditions are met (notably external power). The only system
/// lever that keeps the machine — and therefore the display — awake on lid
/// close is `pmset disablesleep`, which requires root. Standard IOKit power
/// assertions (`caffeinate`) only block *idle* sleep, not lid-close sleep, so
/// they do not help here.
///
/// We obtain root for that one command via `osascript … with administrator
/// privileges`, which shows the native password prompt. The app is not
/// sandboxed, and this avoids shipping a privileged helper. The setting
/// persists in the system power prefs across reboots, so we only *write* it
/// when the toggle changes (one prompt per change) and merely *read* it (no
/// prompt) at launch via `refreshFromSystem()`.
///
/// Note: `disablesleep` disables *all* automatic sleep (idle included), because
/// macOS exposes no lid-close-only knob. The UI surfaces this trade-off.
final class DisplaySleepManager: ObservableObject {

    // MARK: Singleton

    static let shared = DisplaySleepManager()

    // MARK: Published state

    /// Mirrors the system `SleepDisabled` pmset value. The menu toggle binds
    /// to this, so it always reflects the true system state rather than an
    /// optimistic one.
    @Published private(set) var keepDisplayAwake: Bool

    // MARK: Private

    private let workQueue = DispatchQueue(label: "com.macaveli.displaysleep", qos: .userInitiated)

    private init() {
        keepDisplayAwake = UserDefaults.standard.bool(forKey: PreferenceKey.keepDisplayAwakeOnLidClose.rawValue)
    }

    // MARK: API

    /// Apply a new value. Runs `pmset -a disablesleep <0|1>` with admin rights
    /// off the main thread. On success, persists and publishes the new value;
    /// if the user cancels the password prompt (or the command fails), the
    /// published value is left unchanged so the toggle snaps back.
    func setKeepDisplayAwake(_ enabled: Bool) {
        guard enabled != keepDisplayAwake else { return }
        workQueue.async { [weak self] in
            let ok = DisplaySleepManager.runPMSet(disableSleep: enabled)
            DispatchQueue.main.async {
                guard let self else { return }
                if ok {
                    self.keepDisplayAwake = enabled
                    UserDefaults.standard.set(enabled, forKey: PreferenceKey.keepDisplayAwakeOnLidClose.rawValue)
                } else {
                    // The user cancelled or the command failed. Nudge SwiftUI to
                    // re-read the (unchanged) value so a toggle that flipped
                    // optimistically snaps back to its real state.
                    self.objectWillChange.send()
                }
            }
        }
    }

    /// Sync our state to the live system value without prompting (read-only, no
    /// root needed). Call at launch so the toggle reflects reality even if
    /// `disablesleep` was changed outside the app or reset by the system.
    func refreshFromSystem() {
        workQueue.async { [weak self] in
            guard let actual = DisplaySleepManager.readSleepDisabled() else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                if actual != self.keepDisplayAwake {
                    self.keepDisplayAwake = actual
                }
                UserDefaults.standard.set(actual, forKey: PreferenceKey.keepDisplayAwakeOnLidClose.rawValue)
            }
        }
    }

    // MARK: - pmset plumbing

    /// Runs `pmset -a disablesleep <0|1>` as root via osascript's
    /// `with administrator privileges`. Returns true on success (exit 0). A
    /// cancelled password prompt exits non-zero (AppleScript error -128).
    private static func runPMSet(disableSleep: Bool) -> Bool {
        let value = disableSleep ? "1" : "0"
        // The pmset path is hard-coded; the only interpolated token is "0"/"1".
        let script = "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Reads the current `SleepDisabled` value from `pmset -g`. No root needed.
    private static func readSleepDisabled() -> Bool? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        // `pmset -g` includes a line like "  SleepDisabled  1".
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
            if trimmed.hasPrefix("sleepdisabled") {
                return trimmed.contains("1")
            }
        }
        return nil
    }
}
