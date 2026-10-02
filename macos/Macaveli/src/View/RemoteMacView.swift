import SwiftUI
import AppKit

/// "Remote" tweak group — see and control another Mac, GoToMyPC-style: pick it
/// from the list (or paste its address) and click Connect. Screen Sharing.app
/// does the actual session; see `RemoteMacManager`.
struct RemoteMacSection: View {
    @ObservedObject private var manager = RemoteMacManager.shared

    @State private var address = ""
    @State private var copied: String? = nil

    private var typedURL: URL? { RemoteAddress.vncURL(from: address) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            thisMac
            Divider().opacity(0.5)
            connectList
            addressField
            internetHint
        }
        .onAppear { manager.refresh() }
        .onDisappear { manager.stopBrowsing() }
    }

    // MARK: This Mac

    private var thisMac: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Share this Mac")
                    .font(.system(size: 12, weight: .medium))
                Spacer(minLength: 0)
                statusPill
            }

            if manager.sharingEnabled == false {
                Text("Turn on Screen Sharing in System Settings → General → Sharing so your other Macs can connect here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Sharing Settings…") { manager.openSharingSettings() }
                    .controlSize(.small)
            } else if manager.sharingEnabled == true {
                ForEach(manager.localAddresses) { addr in
                    addressRow(addr)
                }
            }
        }
    }

    private var statusPill: some View {
        let (label, color): (String, Color) = {
            switch manager.sharingEnabled {
            case .some(true): return ("ON", .green)
            case .some(false): return ("OFF", .secondary)
            case .none: return ("…", .secondary)
            }
        }()
        return Text(label)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func addressRow(_ addr: LocalAddress) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(addr.value, forType: .string)
            copied = addr.value
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if copied == addr.value { copied = nil }
            }
        } label: {
            HStack(spacing: 6) {
                Text(addr.label.uppercased())
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
                    .frame(width: 92, alignment: .leading)
                Text(addr.value)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Image(systemName: copied == addr.value ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundStyle(copied == addr.value ? Color.green : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Copy — type this on your other Mac to connect here")
    }

    // MARK: Connect

    private var connectList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Connect to a Mac")
                .font(.system(size: 12, weight: .medium))

            if manager.localNetworkDenied {
                Text("Allow Macaveli under System Settings → Privacy & Security → Local Network to find nearby Macs.")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if manager.discovered.isEmpty && manager.saved.isEmpty {
                Text("No Macs found nearby — add one by address below.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            ForEach(manager.discovered) { mac in
                macRow(
                    name: mac.name,
                    detail: manager.unreachable == mac.id ? "Couldn't reach — try again" : "Nearby",
                    busy: manager.resolving == mac.id,
                    connect: { manager.connect(mac) },
                    remove: nil
                )
            }
            ForEach(manager.saved) { mac in
                macRow(
                    name: mac.name,
                    detail: mac.name == mac.address ? "Saved" : mac.address,
                    busy: false,
                    connect: { manager.connect(mac) },
                    remove: { manager.remove(mac) }
                )
            }
        }
    }

    private func macRow(
        name: String, detail: String, busy: Bool,
        connect: @escaping () -> Void, remove: (() -> Void)?
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
            if let remove {
                Button(action: remove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove from saved Macs")
            }
            if busy {
                ProgressView().controlSize(.small)
            } else {
                Button("Connect", action: connect)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 3)
    }

    private var addressField: some View {
        HStack(spacing: 6) {
            TextField("Name or address (e.g. studio.local, 100.101.1.2)", text: $address)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .onSubmit(connectTyped)
            Button("Save") {
                if manager.save(name: "", address: address) { address = "" }
            }
            .controlSize(.small)
            .disabled(typedURL == nil)
            Button("Connect", action: connectTyped)
                .controlSize(.small)
                .disabled(typedURL == nil)
        }
    }

    private func connectTyped() {
        guard let url = typedURL else { return }
        manager.open(url)
    }

    private var internetHint: some View {
        Text("Away from home? Install Tailscale on both Macs and use the other Mac's Tailscale name or 100.x address — don't port-forward Screen Sharing to the internet. Keep the other Mac awake (Never Sleep, above).")
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Remote") {
    RemoteMacSection()
        .padding()
        .frame(width: 360)
}
