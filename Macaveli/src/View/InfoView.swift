import SwiftUI

extension Bundle {
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as! String
    }
}

struct InfoView: View {
    private let version: String

    init(hasPermissions: Bool = false) {
        self.version = Bundle.main.buildNumber
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)

            // Brand mark + name + version, centered
            VStack(spacing: 10) {
                LogoMark()
                    .scaleEffect(2.0)
                    .padding(.bottom, 6)

                Text("Macaveli")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))

                Text("Version \(version)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 22)

            CheckUpdatesButton(label: "Check for Updates")
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

            Spacer(minLength: 28)

            // Minimal footer with tiny tertiary links
            HStack(spacing: 14) {
                MinimalLink(text: "GitHub", url: "https://github.com/jaequery/Macaveli")
                MinimalLinkDot()
                MinimalLink(text: "X", url: "https://x.com/jaequery")
                MinimalLinkDot()
                MinimalLink(text: "jaequery.dev", url: "https://jaequery.dev")
            }
            .font(.system(size: 11))
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MinimalLink: View {
    let text: String
    let url: String
    @State private var hovering = false

    var body: some View {
        Button {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            Text(text)
                .foregroundStyle(hovering ? Color.accentColor : Color.secondary)
                .underline(hovering, color: Color.accentColor)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct MinimalLinkDot: View {
    var body: some View {
        Circle()
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 3, height: 3)
    }
}

#Preview {
    InfoView().frame(width: MAIN_WINDOW_WIDTH, height: 400)
}
