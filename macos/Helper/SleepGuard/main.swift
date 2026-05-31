// Macaveli SleepGuard — a tiny root daemon whose ONLY job is to undo a
// dangerous power state automatically.
//
// Rule (the whole program):  if running on battery AND `pmset disablesleep`
// is 1, set it back to 0.  Nothing else.
//
// Why it exists: the app's "Never Sleep → even when lid is closed" rung sets
// `pmset disablesleep 1`, which can't be scoped to AC. If the user unplugs and
// stuffs the Mac in a bag, it would otherwise stay awake on battery, draining
// and heating with no screen to show a warning and no one to dismiss it. Only a
// process running independently of the app — and with root, since clearing
// `disablesleep` needs root — can fix that unattended. This is that process.
//
// Security posture, by construction:
//   * No IPC. It takes no commands from the app or anyone else, so there is no
//     channel a local attacker could use to drive a root process. It only ever
//     *clears* a setting; it can never enable one.
//   * No interpolated input. The single command it runs is the fixed literal
//     `/usr/bin/pmset -a disablesleep 0` — no injection surface.
//   * Event-driven, never polling. It blocks on an IOKit power-source runloop
//     source and is woken only on a real power-source change, so it costs ~0 CPU
//     and ~0 battery while idle.
//   * Ships inside the signed, notarized app bundle (Contents/MacOS), so its
//     binary lives on a root-owned, SIP/Gatekeeper-validated path — not a
//     user-writable location an attacker could overwrite to gain root.

import Foundation
import IOKit.ps

private let logURL = URL(fileURLWithPath: "/Library/Logs/Macaveli-SleepGuard.log")

private func log(_ message: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(stamp)] \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    if let handle = try? FileHandle(forWritingTo: logURL) {
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    } else {
        try? data.write(to: logURL)
    }
}

/// True when the Mac is currently drawing from the internal battery.
/// Unknown / desktop (no battery) → false, so we never act when unsure.
private func onBatteryPower() -> Bool {
    guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let type = IOPSGetProvidingPowerSourceType(blob)?.takeRetainedValue() as String?
    else { return false }
    return type == kIOPSBatteryPowerValue
}

/// Reads `SleepDisabled` from `pmset -g`. nil if unreadable. No root needed.
private func sleepDisabled() -> Bool? {
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
    for line in output.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.hasPrefix("sleepdisabled") else { continue }
        return trimmed.split(whereSeparator: \.isWhitespace).last.map(String.init) == "1"
    }
    return nil
}

/// `pmset -a disablesleep 0`. We are root, so this needs no prompt. The command
/// is a fixed literal — never interpolate anything into it.
private func clearDisableSleep() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["-a", "disablesleep", "0"]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch {
        log("pmset launch failed: \(error.localizedDescription)")
        return false
    }
    process.waitUntilExit()
    return process.terminationStatus == 0
}

/// The one rule, applied once. Called at startup and on every power change.
private func enforce() {
    guard onBatteryPower() else { return }
    guard sleepDisabled() == true else { return }
    log("On battery with disablesleep=1 — clearing to protect the battery.")
    if clearDisableSleep() {
        log("disablesleep cleared.")
    } else {
        log("Failed to clear disablesleep.")
    }
}

// C-callable callback — must not capture, so it's a top-level function.
private func powerSourceChanged(_ context: UnsafeMutableRawPointer?) {
    enforce()
}

// Catch the boot-on-battery / launch-on-battery state immediately.
enforce()

guard let source = IOPSNotificationCreateRunLoopSource(powerSourceChanged, nil)?.takeRetainedValue() else {
    log("Failed to create power-source notification source — exiting.")
    exit(EXIT_FAILURE)
}
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
log("SleepGuard started; watching power source (event-driven, no polling).")
CFRunLoopRun()
