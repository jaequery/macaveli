import SwiftUI
import ShortcutRecorder
import Sparkle

enum Tab: Hashable {
    case windows, recording, general, about

    var systemImage: String {
        switch self {
        case .windows: return "macwindow.on.rectangle"
        case .recording: return "record.circle"
        case .general: return "gearshape"
        case .about: return "info.circle"
        }
    }

    var helpText: String {
        switch self {
        case .windows: return "Windows"
        case .recording: return "Screen Recording"
        case .general: return "General"
        case .about: return "About"
        }
    }
}

struct AppView: View {
    @State private var selectedTab: Tab = .windows
    @ObservedObject private var recorder = ScreenRecorder.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandBar(selectedTab: $selectedTab, recorder: recorder)

            Divider()

            Group {
                switch selectedTab {
                case .windows:    WindowsTabView()
                case .recording:  ScreenRecordingTabView()
                case .general:    GeneralTabView()
                case .about:      InfoView()
                }
            }

            Divider()

            FooterBar()
        }
        .frame(width: MAIN_WINDOW_WIDTH)
    }
}

/// Shared footer with Quit. Renders on every tab so the action is always
/// available regardless of which page the user is on.
struct FooterBar: View {
    var body: some View {
        HStack {
            Button(action: {
                NSApplication.shared.terminate(0)
            }, label: {
                HStack(spacing: 6) {
                    Text("Quit")
                    Text("⌘Q").foregroundStyle(.secondary).font(.subheadline)
                }
            })
            .keyboardShortcut("Q", modifiers: .command)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

/// Compact branded header — wordmark on the left, recording status pill in the
/// middle (when active), and tab toggles on the right. Replaces the original
/// pair of bare gear/info icons.
struct BrandBar: View {
    @Binding var selectedTab: Tab
    @ObservedObject var recorder: ScreenRecorder

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                LogoMark()
                Text("Macaveli")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }

            if recorder.isRecording || recorder.isConverting {
                RecordingStatusPill(recorder: recorder)
                    .transition(.opacity.combined(with: .scale))
            }

            Spacer(minLength: 4)

            HStack(spacing: 2) {
                ForEach([Tab.windows, .recording, .general, .about], id: \.self) { tab in
                    BrandTabButton(tab: tab, selectedTab: $selectedTab, systemImage: tab.systemImage)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .animation(.easeInOut(duration: 0.18), value: recorder.isRecording)
        .animation(.easeInOut(duration: 0.18), value: recorder.isConverting)
    }
}

/// A small chevron-style logomark. Pure SwiftUI so it always renders sharp.
struct LogoMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("X")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 22, height: 22)
        .shadow(color: Color.accentColor.opacity(0.35), radius: 4, x: 0, y: 1)
    }
}

struct BrandTabButton: View {
    let tab: Tab
    @Binding var selectedTab: Tab
    let systemImage: String
    @State private var hovering = false

    private var selected: Bool { selectedTab == tab }

    var body: some View {
        Button {
            selectedTab = tab
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 26)
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected
                              ? Color.accentColor.opacity(0.12)
                              : (hovering ? Color.primary.opacity(0.06) : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(tab.helpText)
    }
}

/// Live status indicator shown in the header while recording or converting.
struct RecordingStatusPill: View {
    @ObservedObject var recorder: ScreenRecorder
    @State private var pulse = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    private var label: String {
        if recorder.isConverting { return "Optimizing…" }
        guard let start = recorder.recordingStartedAt else { return "Recording" }
        let elapsed = max(0, Int(now.timeIntervalSince(start)))
        let m = elapsed / 60
        let s = elapsed % 60
        return String(format: "%d:%02d", m, s)
    }

    private var dotColor: Color {
        recorder.isConverting ? .orange : .red
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
                .opacity(pulse ? 0.35 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(dotColor.opacity(0.12))
        )
        .overlay(
            Capsule().stroke(dotColor.opacity(0.25), lineWidth: 0.5)
        )
        .onAppear { pulse = true }
        .onReceive(timer) { now = $0 }
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}
