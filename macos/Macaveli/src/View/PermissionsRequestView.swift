import SwiftUI

struct PermissionRequestView: View {
    // Computed once per appearance. The running app's location can't change
    // while it's running, so this is stable for the life of the view.
    private let location = PermissionsManager.currentAppLocation()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Permissions Required").font(.headline).foregroundStyle(.orange)
            Text("This app requires the following permissions to function properly:")
                .padding(.top, 1)
                .padding(.bottom, 12)
                .fixedSize(horizontal: false, vertical: true)

            // The single biggest reason a grant "doesn't take": macOS is running
            // a translocated / non-Applications copy, so the toggle the user
            // flipped points at a different binary. Surface that first with a
            // one-click fix — Open Preferences alone is a dead end here.
            if location.needsMove {
                locationBanner
                    .padding(.bottom, 12)
            }

            HStack {
                Text("Accessibility").font(.subheadline)
                Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                Spacer()
                Button("Open Preferences") {
                    PermissionsManager.openPreferences(at: .accessibility)
                }
            }

            if !PermissionsManager.hasScreenRecordingPermission() {
                Divider().padding(.vertical, 8)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Screen Recording").font(.subheadline)
                        Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                        Spacer()
                        Button("Open Preferences") {
                            // Same TCC dance as for Accessibility: macOS only
                            // lists Macaveli in System Settings → Screen
                            // Recording after the app has actually invoked a
                            // capture API. `requestScreenRecordingPermission`
                            // touches SCShareableContent.current, which
                            // registers the bundle with TCC. We then open
                            // Settings so the user can flip the toggle.
                            PermissionsManager.requestScreenRecordingPermission {
                                PermissionsManager.openPreferences(at: .screenRecording)
                            }
                        }
                    }
                    Text("Screen recording only takes effect after a relaunch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Recovery footer. A real Quit & Relaunch button is always here —
            // it's the only thing that applies a freshly granted Screen-Recording
            // toggle (preflight is cached per-process) and the fix for a grant
            // that needs a restart to take. When the app already lives in
            // /Applications, a lingering prompt is usually a stale TCC entry (an
            // old build/copy still holds the toggle), so spell out that recovery.
            Divider().padding(.vertical, 8)
            VStack(alignment: .leading, spacing: 8) {
                if !location.needsMove {
                    Text("Already enabled in the list? Remove Macaveli with the “–” button and add it back.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Spacer()
                    Button("Quit & Relaunch") {
                        PermissionsManager.relaunch()
                    }
                }
            }
        }
    }

    private var locationBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                Text(bannerMessage)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Move to Applications & Relaunch") {
                    PermissionsManager.moveToApplicationsAndRelaunch()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.orange.opacity(0.30), lineWidth: 0.5)
        )
    }

    private var bannerMessage: String {
        switch location {
        case .translocated:
            return "macOS is running Macaveli from a temporary, read-only copy — you opened it straight from the disk image or Downloads. Permissions granted now won’t stick. Move it to your Applications folder and relaunch first."
        case .elsewhere:
            return "Macaveli isn’t in your Applications folder. Permissions are unreliable from here. Move it to Applications and relaunch, then grant access."
        case .applications:
            return ""
        }
    }
}

#Preview {
    PermissionRequestView().padding().frame(width: 380)
}
