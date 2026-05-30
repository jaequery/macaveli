import AppKit
import Foundation
import IOKit.pwr_mgt

// MARK: - NeverSleepMode

/// How aggressively to keep the Mac awake. Three rungs of increasing strength —
/// each rung uses the lightest macOS mechanism that can deliver it.
enum NeverSleepMode: String, CaseIterable {
    /// Normal macOS behavior — the Mac sleeps as configured.
    case off
    /// Keep the screen on while the lid is open (battery or power), via an IOKit
    /// display-sleep assertion — it disables the automatic screen timeout. No
    /// root, and it is released when the app quits, so it leaves nothing behind.
    /// Closing the lid still sleeps — assertions do not survive a lid-close; use
    /// `.evenLidClosed` for that.
    case whileLidOpen = "whileLidOpen"
    /// Stay awake even with the lid shut, on any power source, via
    /// `pmset disablesleep`. Needs root (one password prompt) and persists in
    /// the system power prefs across reboots *and* app removal until turned
    /// off. It is the only macOS lever that survives a lid-close, and it cannot
    /// be scoped to AC only — so on battery it keeps running in a bag. The UI
    /// labels this explicitly and confirms before enabling.
    case evenLidClosed = "evenLidClosed"

    /// One-line description shown under the control for the selected rung.
    var explanation: String {
        switch self {
        case .off:
            return "Your Mac sleeps normally."
        case .whileLidOpen:
            return "Keeps the screen on — no screen timeout, on battery or power. Closing the lid still sleeps. Turns off when you quit Macaveli."
        case .evenLidClosed:
            return "Keeps the screen on, and stays awake even with the lid closed, on battery too — keeps an external display on. Drains battery and adds heat if closed in a bag. Stays on after you quit, until set to Off. Asks for your password."
        }
    }
}

// MARK: - DisplaySleepManager

/// Owns the "Never Sleep" control. See `NeverSleepMode` for the three rungs and
/// the trade-offs behind each mechanism.
///
/// At launch (and whenever the popover reopens) we reconcile to the live system
/// state: `pmset disablesleep == 1` always wins and surfaces as `.evenLidClosed`,
/// so the UI never lies about the strongest, persistent setting — and an older
/// Macaveli build that set `disablesleep` migrates here automatically. Otherwise
/// we restore the saved `.whileLidOpen` assertion (cheap, no prompt) or fall
/// back to `.off`.
final class DisplaySleepManager: ObservableObject {

    // MARK: Singleton

    static let shared = DisplaySleepManager()

    // MARK: Published state

    /// The active mode. The control binds to this, so it always reflects the
    /// true system state rather than an optimistic one.
    @Published private(set) var mode: NeverSleepMode

    // MARK: Private

    /// Target mode while a root transition is in flight, so a second tap is
    /// judged against where we are heading — not the not-yet-committed value.
    /// Only touched on the main thread.
    private var pendingMode: NeverSleepMode?

    private let workQueue = DispatchQueue(label: "com.macaveli.displaysleep", qos: .userInitiated)

    /// IOKit power assertion backing `.whileLidOpen`.
    private var assertionID = IOPMAssertionID(0)
    private var hasAssertion = false

    private init() {
        let saved = UserDefaults.standard.string(forKey: PreferenceKey.neverSleepMode.rawValue)
        mode = NeverSleepMode(rawValue: saved ?? "") ?? .off
    }

    // MARK: API

    /// Switch to `newMode`. Transitions that cross the `.evenLidClosed` boundary
    /// run `pmset disablesleep` as root off the main thread (one password
    /// prompt); every other transition just flips the IOKit assertion locally
    /// with no prompt. On cancel or failure the published mode is left
    /// unchanged so the control snaps back.
    func setMode(_ newMode: NeverSleepMode) {
        // Guard against the in-flight target, not the committed value, so a
        // rapid second tap during the password prompt is not silently dropped.
        let current = pendingMode ?? mode
        guard newMode != current else { return }

        let wantDisableSleep = (newMode == .evenLidClosed)
        let haveDisableSleep = (current == .evenLidClosed)

        // No root needed: only the assertion changes (off <-> whileLidOpen).
        guard wantDisableSleep != haveDisableSleep else {
            applyAssertion(for: newMode)
            commit(newMode)
            return
        }

        // Entering `.evenLidClosed` is a persistent, system-wide change — make
        // the user confirm before we even raise the password prompt.
        if wantDisableSleep, !confirmEnableEvenLidClosed() {
            objectWillChange.send() // snap the control back to its current rung
            return
        }

        pendingMode = newMode
        workQueue.async { [weak self] in
            let result = DisplaySleepManager.runPMSet(disableSleep: wantDisableSleep)
            DispatchQueue.main.async {
                guard let self else { return }
                self.pendingMode = nil
                switch result {
                case .success:
                    self.applyAssertion(for: newMode)
                    self.commit(newMode)
                case .cancelled:
                    // User dismissed the password prompt — snap back silently.
                    self.objectWillChange.send()
                case .failed(let message):
                    self.presentFailure(message)
                    self.objectWillChange.send()
                }
            }
        }
    }

    /// Reconcile to the live system state without prompting (read-only, no root).
    /// Call at launch and on popover reopen so an external `pmset` change is
    /// reflected. `disablesleep == 1` always wins; otherwise keep/restore the
    /// (non-persistent) assertion mode.
    func refreshFromSystem() {
        workQueue.async { [weak self] in
            let sleepDisabled = DisplaySleepManager.readSleepDisabled()
            DispatchQueue.main.async {
                guard let self else { return }
                let resolved: NeverSleepMode
                if sleepDisabled == true {
                    resolved = .evenLidClosed
                } else if self.mode == .whileLidOpen {
                    resolved = .whileLidOpen
                } else {
                    resolved = .off
                }
                self.applyAssertion(for: resolved)
                if resolved != self.mode { self.mode = resolved }
                UserDefaults.standard.set(resolved.rawValue, forKey: PreferenceKey.neverSleepMode.rawValue)
            }
        }
    }

    // MARK: - Mode plumbing

    private func commit(_ newMode: NeverSleepMode) {
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: PreferenceKey.neverSleepMode.rawValue)
    }

    /// Hold the display assertion for any non-`off` mode; release it for `.off`.
    /// `.evenLidClosed` also leans on `disablesleep` for the lid-closed case, but
    /// holding the assertion keeps the screen lit while the lid is open too.
    private func applyAssertion(for mode: NeverSleepMode) {
        if mode == .off { releaseAssertion() } else { createAssertion() }
    }

    private func createAssertion() {
        guard !hasAssertion else { return }
        // Prevent *display* idle sleep, not just system sleep — this disables the
        // automatic screen timeout (the `caffeinate -d` lever) on any power
        // source, battery included, with no root. Keeping the display lit keeps
        // the system awake too, so this one assertion covers both.
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Macaveli: Keep screen on" as CFString,
            &assertionID
        )
        hasAssertion = (result == kIOReturnSuccess)
    }

    private func releaseAssertion() {
        guard hasAssertion else { return }
        IOPMAssertionRelease(assertionID)
        hasAssertion = false
        assertionID = IOPMAssertionID(0)
    }

    // MARK: - User prompts

    /// Modal confirmation shown before enabling `.evenLidClosed`, because the
    /// change is system-wide, persists after Macaveli quits, and keeps the Mac
    /// awake on battery. Returns true to proceed to the password prompt.
    private func confirmEnableEvenLidClosed() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Keep your Mac awake even when the lid is closed?"
        alert.informativeText = """
        This keeps the Mac running with the lid shut, on battery as well as power — handy with an external display, but it will drain the battery and add heat if the Mac is closed in a bag.

        It stays in effect even after you quit Macaveli, until you set Never Sleep back to Off. You'll be asked for your password to apply it.
        """
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func presentFailure(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't change the sleep setting"
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.informativeText = trimmed.isEmpty
            ? "macOS rejected the change. This can happen on Macs managed by an organization (MDM)."
            : trimmed
        alert.runModal()
    }

    // MARK: - pmset plumbing

    private enum PMSetResult {
        case success
        case cancelled
        case failed(String)
    }

    /// Runs `pmset -a disablesleep <0|1>` as root via osascript's
    /// `with administrator privileges`. A cancelled prompt reports `.cancelled`
    /// (AppleScript error -128); any other non-zero exit reports `.failed`.
    private static func runPMSet(disableSleep: Bool) -> PMSetResult {
        let value = disableSleep ? "1" : "0"
        // Both binary paths are hard-coded and SIP-protected; the only
        // interpolated token is the literal "0"/"1". Never interpolate
        // user-controlled data into this script.
        let script = "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        let errPipe = Pipe()
        process.standardError = errPipe
        do {
            try process.run()
        } catch {
            return .failed(error.localizedDescription)
        }
        // Drain stderr before waiting so a verbose error can't fill the pipe
        // buffer and deadlock waitUntilExit().
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if process.terminationStatus == 0 { return .success }
        let message = String(data: errData, encoding: .utf8) ?? ""
        // osascript reports a user-cancelled auth prompt as error -128.
        if message.contains("-128") { return .cancelled }
        return .failed(message)
    }

    /// Reads the current `SleepDisabled` value from `pmset -g`. No root needed.
    /// Returns nil if the value is absent or unreadable.
    private static func readSleepDisabled() -> Bool? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        // `pmset -g` prints a line like "  SleepDisabled<tab><tab>1" — note the
        // separators are tabs, so split on any whitespace and take the value.
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
            guard trimmed.hasPrefix("sleepdisabled") else { continue }
            return trimmed.split(whereSeparator: \.isWhitespace).last.map(String.init) == "1"
        }
        return nil
    }
}
