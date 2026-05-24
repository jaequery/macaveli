import SwiftUI
import ShortcutRecorder
import LaunchAtLogin

// MARK: - Top-level cheatsheet view

struct CheatsheetView: View {
    @State private var openSection: CheatSectionID? = nil
    @State private var hasAXPermission = PermissionsManager.hasAccessibilityPermission()
    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            CheatBrandBar()
            Divider()

            if hasAXPermission {
                ScrollView {
                    VStack(spacing: 0) {
                        CheatSection(
                            id: .snap,
                            title: "Snap",
                            openSection: $openSection,
                            rows: snapRows,
                            settings: { SnapSettingsStrip() }
                        )
                        SectionDivider()
                        CheatSection(
                            id: .drag,
                            title: "Drag",
                            openSection: $openSection,
                            rows: dragRows,
                            settings: { DragSettingsStrip() }
                        )
                        SectionDivider()
                        CheatSection(
                            id: .record,
                            title: "Record",
                            openSection: $openSection,
                            rows: recordRows,
                            settings: { RecordSettingsStrip() }
                        )
                        SectionDivider()
                        CheatSection(
                            id: .annotate,
                            title: "Annotate",
                            openSection: $openSection,
                            rows: annotateRows,
                            settings: { AnnotateSettingsStrip() }
                        )
                        SectionDivider()
                        CheatSection(
                            id: .paste,
                            title: "Paste",
                            openSection: $openSection,
                            rows: pasteRows,
                            settings: { PasteSettingsStrip() }
                        )
                    }
                    .padding(.vertical, 6)
                }
            } else {
                PermissionRequestView()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
            }

            CheatFooterBar()
        }
        .frame(width: MAIN_WINDOW_WIDTH)
        .onReceive(permissionTimer) { _ in
            hasAXPermission = PermissionsManager.hasAccessibilityPermission()
        }
    }

    // Static row definitions per section — used both for rendering and for
    // filter matching.
    private var snapRows: [CheatRowSpec] {
        [
            .init(type: .maximize, label: "Maximize", desc: "Fill the screen"),
            .init(type: .center, label: "Center", desc: "Re-center without resizing"),
            .init(type: .leftHalf, label: "Left half", desc: "Fill the left half"),
            .init(type: .rightHalf, label: "Right half", desc: "Fill the right half"),
        ]
    }
    private var dragRows: [CheatRowSpec] {
        [
            .init(type: .move, label: "Move window", desc: "Hold + drag anywhere"),
            .init(type: .resize, label: "Resize window", desc: "Hold + drag, quadrant-aware"),
        ]
    }
    private var recordRows: [CheatRowSpec] {
        [
            .init(type: .record, label: "Toggle recording", desc: "Start or stop a screen capture"),
        ]
    }
    private var annotateRows: [CheatRowSpec] {
        [
            .init(type: .annotate, label: "Annotate", desc: "Annotate the clipboard image"),
        ]
    }
    private var pasteRows: [CheatRowSpec] {
        [
            .init(type: .paste, label: "Show clipboard history", desc: "Browse and paste recent clipboard items"),
        ]
    }
}

// MARK: - Section primitives

enum CheatSectionID: Hashable { case snap, drag, record, annotate, paste }

struct CheatRowSpec: Identifiable {
    var id: ShortcutType { type }
    let type: ShortcutType
    let label: String
    let desc: String?
}

struct CheatSection<Settings: View>: View {
    let id: CheatSectionID
    let title: String
    @Binding var openSection: CheatSectionID?
    let rows: [CheatRowSpec]
    @ViewBuilder let settings: () -> Settings

    @State private var gearHover: Bool = false

    private var isOpen: Bool { openSection == id }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            openSection = isOpen ? nil : id
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 20, height: 18)
                            .foregroundStyle(isOpen ? Color.accentColor : Color.secondary)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(isOpen
                                          ? Color.accentColor.opacity(0.14)
                                          : (gearHover ? Color.primary.opacity(0.08) : Color.clear))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { gearHover = $0 }
                    .help(isOpen ? "Close settings" : "Configure \(title)")
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 2)

                if isOpen {
                    settings()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                VStack(spacing: 1) {
                    ForEach(rows) { row in
                        CheatRow(spec: row)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
        }
    }
}

struct SectionDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 12)
            .opacity(0.6)
    }
}

// MARK: - Single cheatsheet row (read-only display)

struct CheatRow: View {
    let spec: CheatRowSpec
    @State private var hovering = false
    @State private var userShortcut: UserShortcut

    init(spec: CheatRowSpec) {
        self.spec = spec
        let loaded = ShortcutsManager.shared.load(for: spec.type)
            ?? UserShortcut(type: spec.type, mouseButton: .none)
        self._userShortcut = State(initialValue: loaded)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            KeyCapsView(userShortcut: userShortcut)
                .frame(width: 130, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(spec.label)
                    .font(.system(size: 12.5))
                if let desc = spec.desc {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(hovering ? Color.primary.opacity(0.04) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onAppear(perform: reload)
        // The settings strips may rewrite this binding; the simplest way to
        // stay in sync is to re-read when we re-appear.
    }

    private func reload() {
        if let loaded = ShortcutsManager.shared.load(for: spec.type) {
            userShortcut = loaded
        }
    }
}

// MARK: - Key-cap rendering

struct KeyCapsView: View {
    let userShortcut: UserShortcut

    var body: some View {
        HStack(spacing: 3) {
            if let shortcut = userShortcut.shortcut {
                ForEach(modifierGlyphs(shortcut.modifierFlags), id: \.self) { g in
                    KeyCap(text: g)
                }
                if let key = keyGlyph(for: shortcut) {
                    KeyCap(text: key)
                } else if userShortcut.type.isMouseDriven {
                    Text("·")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 1)
                    KeyCap(text: dragGlyph(for: userShortcut), style: .pill)
                }
            } else {
                Text("—")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func modifierGlyphs(_ flags: NSEvent.ModifierFlags) -> [String] {
        var out: [String] = []
        if flags.contains(.control) { out.append("ctrl") }
        if flags.contains(.option)  { out.append("opt") }
        if flags.contains(.shift)   { out.append("shift") }
        if flags.contains(.command) { out.append("cmd") }
        return out
    }

    private func keyGlyph(for shortcut: Shortcut) -> String? {
        // Mouse-driven actions intentionally have no main key — the drag is
        // the "key". We surface this elsewhere as a pill cap.
        if userShortcut.type.isMouseDriven { return nil }
        // Prefer the keyCode → glyph mapping for special keys. ShortcutRecorder
        // populates `charactersIgnoringModifiers` with Cocoa private-use
        // codepoints for arrows/function keys (NSUpArrowFunctionKey = 0xF700,
        // …) which render as the font's missing-glyph box.
        if let glyph = KeyCodeGlyph.glyph(for: shortcut.keyCode) {
            return glyph
        }
        if let chars = shortcut.charactersIgnoringModifiers, !chars.isEmpty,
           chars.unicodeScalars.allSatisfy({ $0.value < 0xE000 || $0.value > 0xF8FF }) {
            return chars.uppercased()
        }
        return nil
    }

    private func dragGlyph(for user: UserShortcut) -> String {
        switch user.mouseButton {
        case .none:  return "drag"
        case .left:  return "click+drag"
        case .right: return "r-click+drag"
        }
    }
}

struct KeyCap: View {
    enum Style { case key, pill }
    let text: String
    var style: KeyCap.Style = .key

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.primary.opacity(0.92))
            .padding(.horizontal, style == .pill ? 7 : 5)
            .padding(.vertical, style == .pill ? 2 : 2)
            .frame(minWidth: style == .pill ? nil : 18, minHeight: 18)
            .background(
                RoundedRectangle(cornerRadius: style == .pill ? 9 : 4, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: style == .pill ? 9 : 4, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }
}

enum KeyCodeGlyph {
    static func glyph(for code: KeyCode) -> String? {
        switch code {
        case .upArrow:          return "↑"
        case .downArrow:        return "↓"
        case .leftArrow:        return "←"
        case .rightArrow:       return "→"
        case .ansiLeftBracket:  return "["
        case .ansiRightBracket: return "]"
        case .ansiSemicolon:    return ";"
        case .ansiQuote:        return "'"
        case .ansiComma:        return ","
        case .ansiPeriod:       return "."
        case .ansiSlash:        return "/"
        case .ansiBackslash:    return "\\"
        case .ansiGrave:        return "`"
        case .ansiMinus:        return "-"
        case .ansiEqual:        return "="
        case .space:            return "␣"
        case .tab:              return "⇥"
        case .`return`:         return "↩"
        case .escape:           return "⎋"
        case .delete:           return "⌫"
        case .forwardDelete:    return "⌦"
        default:                return nil
        }
    }
}

// MARK: - Brand / filter / footer bars

struct CheatBrandBar: View {
    @AppStorage(PreferenceKey.showMenuBarIcon.rawValue) private var showMenuBarIcon = true

    var body: some View {
        HStack(spacing: 10) {
            Text("Macaveli")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Spacer(minLength: 4)

            Menu {
                LaunchAtLogin.Toggle()
                Toggle(isOn: $showMenuBarIcon) {
                    Text("Show menu bar icon")
                }
                Divider()
                CheckUpdatesButton(label: "Check for Updates…")
                Button("About Macaveli") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
                Divider()
                Button("Quit Macaveli") { NSApp.terminate(nil) }
                    .keyboardShortcut("Q", modifiers: .command)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

/// Footer only renders during recording or conversion; when the app is idle
/// the bar disappears entirely so the popover ends right after the last
/// section.
struct CheatFooterBar: View {
    @ObservedObject private var recorder = ScreenRecorder.shared
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    var body: some View {
        if recorder.isRecording || recorder.isConverting {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 8) {
                    if recorder.isRecording {
                        Circle().fill(Color.red)
                            .frame(width: 7, height: 7)
                        Text("Recording \(elapsed)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    } else {
                        ProgressView().controlSize(.small)
                        Text("Optimizing…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onReceive(timer) { now = $0 }
        }
    }

    private var elapsed: String {
        guard let start = recorder.recordingStartedAt else { return "0:00" }
        let s = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Per-section settings strips

struct SnapSettingsStrip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            BindingEditorRow(type: .maximize, label: "Maximize")
            BindingEditorRow(type: .center, label: "Center")
            BindingEditorRow(type: .leftHalf, label: "Left half")
            BindingEditorRow(type: .rightHalf, label: "Right half")
        }
    }
}

struct DragSettingsStrip: View {
    @AppStorage(PreferenceKey.useQuadrants.rawValue) private var useQuadrants = true
    @AppStorage(PreferenceKey.focusOnApp.rawValue) private var focusOnApp = true

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            BindingEditorRow(type: .move, label: "Move")
            BindingEditorRow(type: .resize, label: "Resize")
            StripSegmentedRow(title: "Quadrant", selection: $useQuadrants,
                              options: [(false, "Off"), (true, "On")])
            StripSegmentedRow(title: "Focus", selection: $focusOnApp,
                              options: [(false, "Off"), (true, "On")])
        }
    }
}

struct RecordSettingsStrip: View {
    @AppStorage(PreferenceKey.recordingFormat.rawValue) private var format = RecordingFormat.mp4.rawValue
    @AppStorage(PreferenceKey.recordingSaveFolder.rawValue) private var saveFolder = ""
    @AppStorage(PreferenceKey.recordingGifMaxSeconds.rawValue) private var gifMaxSeconds = 30
    @AppStorage(PreferenceKey.recordingGifMaxHeight.rawValue) private var gifMaxHeight = 1080
    @AppStorage(PreferenceKey.recordingGifFps.rawValue) private var gifFps = GifFps.defaultValue.rawValue
    @AppStorage(PreferenceKey.recordingOptimizeMP4.rawValue) private var optimizeMP4 = false
    @AppStorage(PreferenceKey.recordingQuality.rawValue) private var quality = RecordingQuality.defaultValue.rawValue
    @AppStorage(PreferenceKey.recordingFps.rawValue) private var fps = RecordingFps.defaultValue.rawValue
    @AppStorage(PreferenceKey.recordingDemoMode.rawValue) private var demoMode = false
    @AppStorage(PreferenceKey.recordingCountdownSeconds.rawValue) private var countdownSeconds = 3

    private var folderDisplayName: String {
        let resolved = saveFolder.isEmpty
            ? (FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path ?? "~/Desktop")
            : saveFolder
        return (resolved as NSString).abbreviatingWithTildeInPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            BindingEditorRow(type: .record, label: "Hotkey")
            StripSegmentedRow(title: "Format", selection: $format,
                              options: RecordingFormat.allCases.map { ($0.rawValue, $0.rawValue) })

            if format == RecordingFormat.mp4.rawValue {
                StripSegmentedRow(title: "Quality", selection: $quality,
                                  options: RecordingQuality.allCases.map { ($0.rawValue, $0.rawValue) })
                StripSegmentedRow(title: "Frame rate", selection: $fps,
                                  options: RecordingFps.allCases.map { ($0.rawValue, $0.label) })
                StripSegmentedRow(title: "Optimize", selection: $optimizeMP4,
                                  options: [(false, "Off"), (true, "On")])
            } else {
                StripSegmentedRow(title: "GIF fps", selection: $gifFps,
                                  options: GifFps.allCases.map { ($0.rawValue, $0.label) })
                StripStepperRow(title: "Max height", value: $gifMaxHeight, suffix: "px")
                StripStepperRow(title: "Max seconds", value: $gifMaxSeconds, suffix: "s")
            }

            StripSegmentedRow(title: "Countdown", selection: $countdownSeconds,
                              options: [(0, "Off"), (3, "3 s"), (5, "5 s")])
            StripSegmentedRow(title: "Mode", selection: $demoMode,
                              options: [(false, "Default"), (true, "Product demo")])

            HStack(spacing: 8) {
                Text("Save to")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)
                Text(folderDisplayName)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Choose…") { pickFolder() }
                    .buttonStyle(.borderless)
                    .controlSize(.mini)
            }
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        let current = saveFolder.isEmpty
            ? (FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory())
            : saveFolder
        panel.directoryURL = URL(fileURLWithPath: (current as NSString).expandingTildeInPath, isDirectory: true)
        if panel.runModal() == .OK, let url = panel.url {
            saveFolder = url.path
        }
    }
}

struct AnnotateSettingsStrip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            BindingEditorRow(type: .annotate, label: "Hotkey")
        }
    }
}

struct PasteSettingsStrip: View {
    @AppStorage(PreferenceKey.pasteHistorySize.rawValue) private var historySize = 100
    @ObservedObject private var manager = PasteManager.shared

    private var formattedBytes: String {
        let total = manager.items.reduce(0) { $0 + $1.byteSize }
        return PasteManager.byteCountString(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            BindingEditorRow(type: .paste, label: "Hotkey")
            HStack(spacing: 8) {
                Text("History size")
                    .font(.system(size: stripLabelFontSize))
                    .foregroundStyle(.secondary)
                    .frame(width: stripLabelWidth, alignment: .leading)
                Stepper(
                    value: $historySize,
                    in: 25...500,
                    step: 25
                ) {
                    Text("\(historySize) items")
                        .font(.system(size: stripLabelFontSize))
                        .monospacedDigit()
                }
                .controlSize(.mini)
            }
            HStack(spacing: 8) {
                Text("")
                    .frame(width: stripLabelWidth, alignment: .leading)
                Button("Clear history") {
                    PasteManager.shared.clearAll()
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
                .foregroundStyle(.red)
            }
            HStack(spacing: 8) {
                Text("")
                    .frame(width: stripLabelWidth, alignment: .leading)
                Text("\(manager.items.count) items · \(formattedBytes) used")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Strip primitives

private let stripLabelWidth: CGFloat = 80
private let stripLabelFontSize: CGFloat = 11

struct StripSegmentedRow<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [(T, String)]

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: stripLabelFontSize))
                .foregroundStyle(.secondary)
                .frame(width: stripLabelWidth, alignment: .leading)
            Picker("", selection: $selection) {
                ForEach(options, id: \.0) { (value, label) in
                    Text(label).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.mini)
            .labelsHidden()
        }
    }
}

struct StripStepperRow: View {
    let title: String
    @Binding var value: Int
    let suffix: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: stripLabelFontSize))
                .foregroundStyle(.secondary)
                .frame(width: stripLabelWidth, alignment: .leading)
            TextField("", value: $value, formatter: NumberFormatter())
                .textFieldStyle(.roundedBorder)
                .controlSize(.mini)
                .frame(width: 56)
            Text(suffix)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

/// One row of the per-section bindings editor — action label on the left,
/// ShortcutRecorder control on the right.
struct BindingEditorRow: View {
    let type: ShortcutType
    let label: String
    @State private var userShortcut: UserShortcut

    init(type: ShortcutType, label: String) {
        self.type = type
        self.label = label
        let loaded = ShortcutsManager.shared.load(for: type)
            ?? UserShortcut(type: type, mouseButton: .none)
        self._userShortcut = State(initialValue: loaded)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: stripLabelFontSize))
                .foregroundStyle(.secondary)
                .frame(width: stripLabelWidth, alignment: .leading)
            ShortcutNSView(shortcut: $userShortcut.shortcut)
                .onChange(of: userShortcut.shortcut) { newValue in
                    if newValue == nil {
                        ShortcutsManager.shared.delete(for: type)
                    } else {
                        ShortcutsManager.shared.save(userShortcut)
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview("Cheatsheet") {
    CheatsheetView()
        .frame(width: MAIN_WINDOW_WIDTH, height: 520)
}
