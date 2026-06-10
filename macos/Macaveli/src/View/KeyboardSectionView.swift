import SwiftUI

/// "Key Repeat" menu section — fast key repeat past the macOS slider floor.
/// See `KeyRepeatManager` and CLAUDE.md.
struct KeyboardSectionView: View {
    @StateObject private var manager = KeyRepeatManager.shared

    // In-flight slider values (15 ms units). Committed to the global domain on
    // drag-release / button tap, not on every tick.
    @State private var delay: Double = 0
    @State private var interval: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if manager.karabinerPresent { karabinerNote }
            delaySlider
            intervalSlider
            buttonRow
            if manager.needsLogout { logoutBanner }
        }
        .animation(.easeInOut(duration: 0.16), value: manager.needsLogout)
        .onAppear {
            manager.refreshFromSystem()
            delay = Double(manager.delayUnits)
            interval = Double(manager.intervalUnits)
        }
    }

    private var karabinerNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            Text("Karabiner-Elements controls key repeat and will override these settings.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Sliders

    private var delaySlider: some View {
        sliderRow(
            title: "Delay until repeat",
            value: $delay,
            range: KeyRepeatManager.delayUnitRange
        )
    }

    private var intervalSlider: some View {
        sliderRow(
            title: "Key repeat rate",
            value: $interval,
            range: KeyRepeatManager.intervalUnitRange
        )
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(KeyRepeatManager.ms(Int(value.wrappedValue.rounded()))) ms")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: value,
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1,
                onEditingChanged: { editing in
                    if !editing { commit() }
                }
            )
            .controlSize(.small)
        }
    }

    // MARK: - Buttons

    private var buttonRow: some View {
        HStack(spacing: 8) {
            Button {
                manager.applyFastPreset()
                syncFromManager()
            } label: {
                Label("Fast", systemImage: "hare")
                    .font(.system(size: 11))
            }
            .controlSize(.small)
            .help("150 ms delay, 15 ms repeat — past the System Settings floor")

            Spacer()

            Button("Reset to macOS Default") {
                manager.resetToSystemDefault()
                syncFromManager()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .font(.system(size: 11))
            .disabled(!manager.isCustomized)
        }
    }

    /// Contextual banner — appears only when this session changed the values,
    /// so a logout is actually needed. Mirrors the orange permission-banner
    /// treatment in CheatSection, tinted with the accent instead.
    private var logoutBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
            Text("Takes full effect after you log out.")
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("Log Out…") { manager.logOut() }
                .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 0.5)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Commit helpers

    private func commit() {
        manager.apply(
            delayUnits: Int(delay.rounded()),
            intervalUnits: Int(interval.rounded())
        )
        syncFromManager()
    }

    private func syncFromManager() {
        delay = Double(manager.delayUnits)
        interval = Double(manager.intervalUnits)
    }
}
