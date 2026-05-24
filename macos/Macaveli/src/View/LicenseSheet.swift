import SwiftUI

/// License entry sheet. Surfaced from the brand-bar gear menu and from
/// the trial-expired banner.
struct LicenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var license = LicenseManager.shared

    @State private var email: String = ""
    @State private var key: String = ""
    @State private var activating = false
    @State private var error: String?
    @State private var success = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            switch license.state {
            case .licensed(let activeEmail):
                licensedView(email: activeEmail)
            default:
                activationForm
            }

            footer
        }
        .padding(20)
        .frame(width: 360)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                LogoMark()
                Text("Macaveli License")
                    .font(.system(size: 15, weight: .semibold))
            }
            Text(headerSubtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
    }

    private var headerSubtitle: String {
        switch license.state {
        case .licensed: return "Thanks for supporting Macaveli."
        case .trialing(let d): return "You're on a trial — \(d) day\(d == 1 ? "" : "s") left."
        case .trialExpired: return "Your trial has ended. Enter a key to keep using Macaveli."
        }
    }

    private var activationForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            field(label: "Email", placeholder: "you@example.com", text: $email)
            field(label: "License key", placeholder: "Paste the key from your receipt", text: $key, monospaced: true)

            if let error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.red)
            }
        }
    }

    private func licensedView(email: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.green)
                Text("Activated to \(email)")
                    .font(.system(size: 12))
            }
            Button("Deactivate this Mac") {
                license.deactivate()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if !license.isLicensed {
                Button("Buy a License") { openBuyPage() }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
            }
            Spacer()
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
            if !license.isLicensed {
                Button(activating ? "Activating…" : "Activate") { activate() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(activating || email.isEmpty || key.isEmpty)
            }
        }
    }

    // MARK: - Helpers

    private func field(label: String, placeholder: String, text: Binding<String>, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: monospaced ? .monospaced : .default))
                .disableAutocorrection(true)
        }
    }

    private func activate() {
        activating = true
        error = nil
        Task {
            let result = await license.activate(email: email, key: key)
            await MainActor.run {
                activating = false
                switch result {
                case .success:
                    success = true
                    dismiss()
                case .failure(let err):
                    error = err.errorDescription
                }
            }
        }
    }

    private func openBuyPage() {
        if let url = URL(string: "https://macaveli.app/buy") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    LicenseSheet()
}
