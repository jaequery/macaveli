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
            Text("Key Repeat")
                .font(.system(size: 12.5))
            if manager.karabinerPresent { karabinerNote }
            delaySlider
            intervalSlider
            buttonRow
            logoutBanner
        }
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
            title: "Delay before repeat",
            value: $delay,
            range: KeyRepeatManager.delayUnitRange
        )
    }

    private var intervalSlider: some View {
        sliderRow(
            title: "Repeat speed",
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
                    .font(.system(size: 11))
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
            Button("Fast") {
                manager.applyFastPreset()
                syncFromManager()
            }
            .controlSize(.small)

            Button("Reset to macOS default") {
                manager.resetToSystemDefault()
                syncFromManager()
            }
            .controlSize(.small)
            .disabled(!manager.isCustomized)

            Spacer()
        }
    }

    private var logoutBanner: some View {
        HStack(spacing: 8) {
            Text("Takes full effect after you log out.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Log Out…") { manager.logOut() }
                .controlSize(.small)
        }
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
