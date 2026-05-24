import SwiftUI

struct PermissionRequestView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Permissions Required").font(.headline).foregroundStyle(.orange)
            Text("This app requires the following permissions to function properly:")
                .padding(.top, 1)
                .padding(.bottom, 12)
                .lineLimit(2)
            HStack {
                Text("Accessibility").font(.subheadline)
                Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                Spacer()
                Button("Open Preferences") {
                    PermissionsManager.openPreferences(at: .accessibility)
                }
            }

            if !PermissionsManager.hasScreenRecordingPermission() {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
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
                    Text("Quit and relaunch Macaveli after granting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    PermissionRequestView().padding()
}
