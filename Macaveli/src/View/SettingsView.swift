import SwiftUI
import ShortcutRecorder
import Sparkle
import LaunchAtLogin

// MARK: - Tab pages

/// Window management — Move, Resize, Maximize, Center shortcuts.
struct WindowsTabView: View {
    @State private var hasPermissions = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let types: [ShortcutType] = [.move, .resize, .maximize, .center, .leftHalf, .rightHalf]

    var body: some View {
        TabScrollContainer {
            VStack(alignment: .leading, spacing: 14) {
                TabHeader(
                    title: "Windows",
                    subtitle: "Hold a shortcut, then drag the mouse to move or resize."
                )

                if hasPermissions {
                    ShortcutList(types: Self.types)
                } else {
                    PermissionRequestView().padding(.top, 4)
                }
            }
        }
        .onAppear { refreshPermissions() }
        .onReceive(timer) { _ in refreshPermissions() }
    }

    private func refreshPermissions() {
        hasPermissions = PermissionsManager.hasAccessibilityPermission()
    }
}

/// Screen recording — record card, hotkey, format/save folder, optimize toggle.
struct ScreenRecordingTabView: View {
    var body: some View {
        TabScrollContainer {
            VStack(alignment: .leading, spacing: 18) {
                RecordingCard()

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Hotkey")
                    ShortcutList(types: [.record])
                }

                Divider()

                RecordingPreferencesView()
            }
        }
    }
}

/// Typical app-wide toggles.
struct GeneralTabView: View {
    @AppStorage(PreferenceKey.showMenuBarIcon.rawValue) private var showMenuBarIcon = true

    var body: some View {
        TabScrollContainer {
            VStack(alignment: .leading, spacing: 14) {
                TabHeader(
                    title: "General",
                    subtitle: "App-wide preferences."
                )

                VStack(alignment: .leading, spacing: 10) {
                    LaunchAtLogin.Toggle()

                    Toggle(isOn: $showMenuBarIcon) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show menu bar icon")
                            Text("Re-open the app to bring the icon back.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Reusable building blocks

/// Standardized scroll container so all tabs share padding + height.
struct TabScrollContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            content()
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Small bold title + secondary subtitle at the top of a tab.
struct TabHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Hero panel at the top of the Screen Recording tab. Gives the app a strong
/// primary action (record / stop) plus a glanceable state readout.
struct RecordingCard: View {
    @ObservedObject private var recorder = ScreenRecorder.shared
    @State private var hovering = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    private var hotkeyText: String {
        guard let recordShortcut = ShortcutsManager.shared.load(for: .record)?.shortcut else { return "" }
        let modifiers = ModifierFlagsFormatter.string(from: recordShortcut.modifierFlags)
        let key = recordShortcut.charactersIgnoringModifiers?.uppercased() ?? ""
        return modifiers + key
    }

    private var elapsedText: String {
        guard let start = recorder.recordingStartedAt else { return "0:00" }
        let elapsed = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", elapsed / 60, elapsed % 60)
    }

    private enum RecordState { case idle, recording, converting }
    private var state: RecordState {
        if recorder.isConverting { return .converting }
        if recorder.isRecording { return .recording }
        return .idle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                statusGlyph
                VStack(alignment: .leading, spacing: 1) {
                    Text(titleText)
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitleText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                if !hotkeyText.isEmpty {
                    Text(hotkeyText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.primary.opacity(0.08))
                        )
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                guard state != .converting else { return }
                ScreenRecorder.shared.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: buttonIcon)
                        .font(.system(size: 12, weight: .bold))
                    Text(buttonLabel)
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(buttonBackground)
                )
                .foregroundStyle(buttonForeground)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(state == .converting)
            .onHover { hovering = $0 }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .onReceive(timer) { now = $0 }
        .animation(.easeInOut(duration: 0.18), value: state)
    }

    @ViewBuilder private var statusGlyph: some View {
        switch state {
        case .idle:
            Image(systemName: "record.circle")
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
        case .recording:
            Image(systemName: "record.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.red)
        case .converting:
            ProgressView()
                .controlSize(.small)
        }
    }

    private var titleText: String {
        switch state {
        case .idle: return "Ready to record"
        case .recording: return "Recording"
        case .converting: return "Optimizing"
        }
    }

    private var subtitleText: String {
        switch state {
        case .idle: return "Capture the primary display."
        case .recording: return elapsedText
        case .converting: return "Saving to disk…"
        }
    }

    private var buttonLabel: String {
        switch state {
        case .idle: return "Start Recording"
        case .recording: return "Stop"
        case .converting: return "Processing…"
        }
    }

    private var buttonIcon: String {
        switch state {
        case .idle: return "record.circle"
        case .recording: return "stop.fill"
        case .converting: return "hourglass"
        }
    }

    private var buttonBackground: Color {
        switch state {
        case .idle: return hovering ? Color.accentColor.opacity(0.9) : Color.accentColor
        case .recording: return hovering ? Color.red.opacity(0.9) : .red
        case .converting: return Color.primary.opacity(0.1)
        }
    }

    private var buttonForeground: Color {
        switch state {
        case .idle, .recording: return .white
        case .converting: return .secondary
        }
    }
}

/// Renders a list of shortcut rows from a list of ShortcutType. Used by both
/// the Windows tab (move/resize/maximize/center) and the Screen Recording tab
/// (record).
struct ShortcutList: View {
    let types: [ShortcutType]
    var body: some View {
        VStack(spacing: 4) {
            ForEach(types, id: \.self) { type in
                ShortcutView(type: type)
            }
        }
    }
}

/// Helper to render ⌃⌥⇧⌘ glyphs for a given modifier mask.
enum ModifierFlagsFormatter {
    static func string(from flags: NSEvent.ModifierFlags) -> String {
        var out = ""
        if flags.contains(.control) { out += "⌃" }
        if flags.contains(.option) { out += "⌥" }
        if flags.contains(.shift) { out += "⇧" }
        if flags.contains(.command) { out += "⌘" }
        return out
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

#Preview("Windows") {
    WindowsTabView().frame(width: MAIN_WINDOW_WIDTH, height: 500)
}

#Preview("Recording") {
    ScreenRecordingTabView().frame(width: MAIN_WINDOW_WIDTH, height: 500)
}

#Preview("General") {
    GeneralTabView().frame(width: MAIN_WINDOW_WIDTH, height: 400)
}
