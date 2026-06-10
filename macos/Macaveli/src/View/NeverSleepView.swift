import SwiftUI

// MARK: - Never Sleep row

/// "Never Sleep" — four rungs of keeping the Mac awake, from off to
/// lid-closed-on-battery. A custom segmented control instead of a Picker so
/// each segment can explain itself *before* it's clicked: hovering a segment
/// opens a small IKEA-manual-style card (diagram + what it does + when to use
/// it). See `NeverSleepMode` for the mechanisms.
struct NeverSleepRow: View {
    @ObservedObject private var displaySleep = DisplaySleepManager.shared

    /// Segment currently under the cursor; drives the delayed popover.
    @State private var hoverTarget: NeverSleepMode? = nil
    /// Segment whose info card is showing (set after a short hover delay).
    @State private var popoverTarget: NeverSleepMode? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Never Sleep")
                .font(.system(size: 12, weight: .medium))

            HStack(spacing: 2) {
                segment(.off, label: "Off", icon: nil)
                segment(.whileLidOpen, label: "Lid Open", icon: nil)
                segment(.evenLidClosed, label: "Closed", icon: "bolt.fill")
                segment(.evenLidClosedBattery, label: "Closed", icon: "battery.25percent")
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )

            Text(displaySleep.mode.explanation)
                .font(.system(size: 11))
                .foregroundStyle(displaySleep.mode == .evenLidClosedBattery
                                 ? AnyShapeStyle(Color.orange)
                                 : AnyShapeStyle(.secondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func segment(_ mode: NeverSleepMode, label: String, icon: String?) -> some View {
        let selected = displaySleep.mode == mode
        let dangerous = mode == .evenLidClosedBattery
        let fill: Color = selected
            ? (dangerous ? Color.orange : Color.accentColor)
            : (hoverTarget == mode ? Color.primary.opacity(0.06) : Color.clear)

        Button {
            hoverTarget = nil
            popoverTarget = nil
            displaySleep.setMode(mode)
        } label: {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 10.5, weight: selected ? .semibold : .medium))
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(selected
                                         ? Color.white
                                         : (dangerous ? Color.orange : Color.secondary))
                }
            }
            .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.85))
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(fill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in hover(mode, inside) }
        .popover(isPresented: Binding(
            get: { popoverTarget == mode },
            set: { if !$0, popoverTarget == mode { popoverTarget = nil } }
        ), arrowEdge: .bottom) {
            NeverSleepInfoCard(mode: mode)
        }
    }

    /// Show the card only after the cursor settles (350 ms) so sweeping across
    /// the control doesn't strobe four popovers.
    private func hover(_ mode: NeverSleepMode, _ inside: Bool) {
        if inside {
            hoverTarget = mode
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if hoverTarget == mode { popoverTarget = mode }
            }
        } else {
            if hoverTarget == mode { hoverTarget = nil }
            if popoverTarget == mode { popoverTarget = nil }
        }
    }
}

// MARK: - Hover info card

/// The hover card: a small diagram in the IKEA-manual register (thin outlines,
/// pictograms, one ✓/✗ verdict), then what the rung does and when to use it.
struct NeverSleepInfoCard: View {
    let mode: NeverSleepMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NeverSleepDiagram(mode: mode)
                .frame(height: 76)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )

            Text(mode.title)
                .font(.system(size: 12, weight: .semibold))

            Text(mode.blurb)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("USE FOR")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
                Text(mode.useFor)
                    .font(.system(size: 11))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if mode == .evenLidClosedBattery { batteryWarning }
        }
        .padding(12)
        .frame(width: 250)
    }

    private var batteryWarning: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            Text("Heat builds with the lid shut, and nothing turns this off for you. Forgotten in a bag it can drain and overheat — switch it off as soon as you're done.")
                .font(.system(size: 10.5))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.orange.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Diagrams

/// One minimal scene per rung. Thin 1.3 pt outlines, pictograms over words,
/// color only as verdict (green ✓ / red ✗) or warning.
struct NeverSleepDiagram: View {
    let mode: NeverSleepMode

    private var ink: Color { Color.primary.opacity(0.75) }

    var body: some View {
        switch mode {
        case .off: offScene
        case .whileLidOpen: lidOpenScene
        case .evenLidClosed: lidClosedPowerScene
        case .evenLidClosedBattery: lidClosedBatteryScene
        }
    }

    /// Closed laptop, asleep: z z z drifting up.
    private var offScene: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ClosedLaptopGlyph(width: 46, ink: ink)
            HStack(alignment: .bottom, spacing: 2) {
                Text("z").font(.system(size: 9, design: .monospaced)).offset(y: -2)
                Text("z").font(.system(size: 11, design: .monospaced)).offset(y: -8)
                Text("z").font(.system(size: 13, design: .monospaced)).offset(y: -15)
            }
            .foregroundStyle(.secondary)
        }
    }

    /// Open laptop, screen lit.
    private var lidOpenScene: some View {
        OpenLaptopGlyph(ink: ink) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 10))
                .foregroundStyle(ink)
        }
    }

    /// Closed laptop feeding an external display, on power: the clamshell setup.
    private var lidClosedPowerScene: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                ClosedLaptopGlyph(width: 40, ink: ink)
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(ink)
            }
            Rectangle()
                .fill(ink)
                .frame(width: 14, height: 1.3)
                .offset(y: -7)
            MonitorGlyph(ink: ink)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
                .padding(.leading, 10)
        }
    }

    /// The do / don't twin panels: short attended session ✓, bag ✗.
    private var lidClosedBatteryScene: some View {
        HStack(spacing: 8) {
            verdictPanel(ok: true, caption: "Short session") {
                HStack(spacing: 6) {
                    ClosedLaptopGlyph(width: 28, ink: ink)
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                        .foregroundStyle(ink)
                }
            }
            verdictPanel(ok: false, caption: "Left in a bag") {
                Image(systemName: "backpack")
                    .font(.system(size: 16))
                    .foregroundStyle(ink)
            }
        }
        .padding(.horizontal, 10)
    }

    private func verdictPanel<Content: View>(
        ok: Bool, caption: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 4) {
            content()
                .frame(maxWidth: .infinity)
                .frame(height: 28)
            Text(caption)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(ok ? Color.green : Color.red)
                .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                .offset(x: 5, y: -5)
        }
    }
}

// MARK: - Glyph primitives

/// Side view of a shut MacBook — a thin rounded wedge.
struct ClosedLaptopGlyph: View {
    var width: CGFloat = 44
    var ink: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .stroke(ink, lineWidth: 1.3)
            .frame(width: width, height: 7)
    }
}

/// Front view of an open MacBook: screen above a trapezoid base. `content`
/// renders centered in the screen.
struct OpenLaptopGlyph<Content: View>: View {
    var ink: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(ink, lineWidth: 1.3)
                    .frame(width: 42, height: 27)
                content()
            }
            TrapezoidShape()
                .stroke(ink, lineWidth: 1.3)
                .frame(width: 56, height: 6)
        }
    }
}

/// External display: screen on a small stand.
struct MonitorGlyph: View {
    var ink: Color

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(ink, lineWidth: 1.3)
                .frame(width: 36, height: 24)
            Rectangle().fill(ink).frame(width: 1.3, height: 5)
            Rectangle().fill(ink).frame(width: 16, height: 1.3)
        }
    }
}

/// The keyboard deck of an open laptop, seen face-on.
struct TrapezoidShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset: CGFloat = rect.width * 0.1
        p.move(to: CGPoint(x: inset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Preview

#Preview("Never Sleep cards") {
    HStack(alignment: .top) {
        ForEach(NeverSleepMode.allCases, id: \.self) { mode in
            NeverSleepInfoCard(mode: mode)
        }
    }
    .padding()
}
