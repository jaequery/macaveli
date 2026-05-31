import Foundation
import AppKit

/// Fast key-repeat control — the "Way 1 / OS defaults writer" design.
///
/// macOS keeps two global knobs for key repeat in `NSGlobalDomain`:
///   • `InitialKeyRepeat` — delay before a held key starts repeating.
///   • `KeyRepeat`        — interval between repeats once it's going.
/// Both are stored as **integer units of 15 ms** (so `KeyRepeat == 1` ⇒ 15 ms).
/// System Settings' sliders stop at a floor (delay 225 ms / interval 30 ms);
/// writing smaller integers directly pushes past that floor — the whole point
/// of this feature.
///
/// We do NOT synthesize repeats ourselves (that's the hypothetical "Way 2"):
/// macOS still does the repeating, we just set the numbers. Consequence: apps
/// only re-read these at launch, so a change is fully live only after logout.
///
/// Set-and-forget: we snapshot the user's original values before the first
/// write so "Reset to macOS default" always works, and we never re-apply on
/// launch — manual System Settings tweaks are left alone.
@MainActor
final class KeyRepeatManager: ObservableObject {
    static let shared = KeyRepeatManager()

    // MARK: - Tuning (all in 15 ms units, matching macOS storage)

    /// Delay-before-repeat slider bounds: 105 ms … 1005 ms.
    static let delayUnitRange: ClosedRange<Int> = 7...67
    /// Repeat-interval slider bounds: 15 ms … 120 ms.
    static let intervalUnitRange: ClosedRange<Int> = 1...8
    /// "Fast" preset: 150 ms delay / 15 ms interval.
    static let fastDelayUnits = 10
    static let fastIntervalUnits = 1

    static let unitMs = 15
    static func ms(_ units: Int) -> Int { units * unitMs }

    // macOS factory defaults, used only to show a sensible number when the
    // user has never customized these (the keys are absent from the domain).
    private static let defaultDelayUnits = 25   // 375 ms
    private static let defaultIntervalUnits = 6 //  90 ms

    // MARK: - Published state (current global values, in 15 ms units)

    @Published private(set) var delayUnits: Int = defaultDelayUnits
    @Published private(set) var intervalUnits: Int = defaultIntervalUnits

    // MARK: - Global-domain pref plumbing (== `defaults write -g`)

    private let initialKeyRepeatKey = "InitialKeyRepeat" as CFString
    private let keyRepeatKey = "KeyRepeat" as CFString
    private let appID = kCFPreferencesAnyApplication
    private let user = kCFPreferencesCurrentUser
    private let host = kCFPreferencesAnyHost

    // Snapshot of the pre-Macaveli values. `nil` element ⇒ the key was absent
    // (pure system default) and Reset should remove it, not write a number.
    private let origDelayKey = PreferenceKey.keyRepeatOrigDelay.rawValue
    private let origIntervalKey = PreferenceKey.keyRepeatOrigInterval.rawValue
    private let snapshotTakenKey = PreferenceKey.keyRepeatSnapshotTaken.rawValue
    /// Sentinel persisted when the original value was absent from the domain.
    private static let absentSentinel = -1

    private init() {
        refreshFromSystem()
    }

    // MARK: - Reads

    /// Re-read the live global values into the published state.
    func refreshFromSystem() {
        delayUnits = readGlobal(initialKeyRepeatKey) ?? Self.defaultDelayUnits
        intervalUnits = readGlobal(keyRepeatKey) ?? Self.defaultIntervalUnits
    }

    /// True when our values differ from the snapshotted original (or no
    /// snapshot exists and they differ from system default) — i.e. there's
    /// something for Reset to undo.
    var isCustomized: Bool {
        guard snapshotTaken else {
            return delayUnits != Self.defaultDelayUnits
                || intervalUnits != Self.defaultIntervalUnits
        }
        let (od, oi) = originalSnapshot()
        return delayUnits != (od ?? Self.defaultDelayUnits)
            || intervalUnits != (oi ?? Self.defaultIntervalUnits)
    }

    // MARK: - Writes

    /// Clamp + write both values to the global domain.
    func apply(delayUnits newDelay: Int, intervalUnits newInterval: Int) {
        snapshotOriginalIfNeeded()

        let d = newDelay.clamped(to: Self.delayUnitRange)
        let i = newInterval.clamped(to: Self.intervalUnitRange)

        writeGlobal(initialKeyRepeatKey, d)
        writeGlobal(keyRepeatKey, i)
        sync()

        delayUnits = d
        intervalUnits = i
    }

    func applyFastPreset() {
        apply(delayUnits: Self.fastDelayUnits, intervalUnits: Self.fastIntervalUnits)
    }

    /// Restore the user's pre-Macaveli values (removing the keys entirely when
    /// they were originally absent). The snapshot is kept so a later change
    /// still knows the true baseline.
    func resetToSystemDefault() {
        let (od, oi) = originalSnapshot()
        writeGlobal(initialKeyRepeatKey, od)   // nil ⇒ remove key
        writeGlobal(keyRepeatKey, oi)
        sync()
        refreshFromSystem()
    }

    // MARK: - Logout (full apply)

    /// Polite, user-confirmed logout so the new repeat values take effect in
    /// every app. Uses the standard System Events logout flow.
    func logOut() {
        let script = "tell application \"System Events\" to log out"
        guard let appleScript = NSAppleScript(source: script) else { return }
        var err: NSDictionary?
        appleScript.executeAndReturnError(&err)
        if let err = err { NSLog("Macaveli: logout request failed: \(err)") }
    }

    // MARK: - Karabiner detection

    /// Karabiner-Elements intercepts the keyboard and reimplements repeat, so
    /// it overrides these settings entirely. Detect it to warn the user.
    var karabinerPresent: Bool {
        let running = NSWorkspace.shared.runningApplications.contains {
            ($0.bundleIdentifier ?? "").hasPrefix("org.pqrs.")
        }
        if running { return true }
        return FileManager.default.fileExists(
            atPath: "/Applications/Karabiner-Elements.app")
    }

    // MARK: - Snapshot helpers

    private var snapshotTaken: Bool {
        UserDefaults.standard.bool(forKey: snapshotTakenKey)
    }

    private func snapshotOriginalIfNeeded() {
        guard !snapshotTaken else { return }
        let d = UserDefaults.standard
        d.set(readGlobal(initialKeyRepeatKey) ?? Self.absentSentinel, forKey: origDelayKey)
        d.set(readGlobal(keyRepeatKey) ?? Self.absentSentinel, forKey: origIntervalKey)
        d.set(true, forKey: snapshotTakenKey)
    }

    /// Returns the snapshotted originals; `nil` element means "was absent".
    private func originalSnapshot() -> (delay: Int?, interval: Int?) {
        let d = UserDefaults.standard
        let rawD = d.integer(forKey: origDelayKey)
        let rawI = d.integer(forKey: origIntervalKey)
        return (rawD == Self.absentSentinel ? nil : rawD,
                rawI == Self.absentSentinel ? nil : rawI)
    }

    // MARK: - CFPreferences global-domain primitives

    private func readGlobal(_ key: CFString) -> Int? {
        let value = CFPreferencesCopyValue(key, appID, user, host)
        return (value as? NSNumber)?.intValue
    }

    private func writeGlobal(_ key: CFString, _ value: Int?) {
        let cf: CFPropertyList? = value.map { NSNumber(value: $0) }
        CFPreferencesSetValue(key, cf, appID, user, host)
    }

    private func sync() {
        CFPreferencesAppSynchronize(appID)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
