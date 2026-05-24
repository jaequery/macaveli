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
                            PermissionsManager.openPreferences(at: .screenRecording)
                        }
                    }
                    Text("Quit and relaunch Macaveli after granting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // F9: Use PermissionsManager abstraction instead of direct AVCaptureDevice call.
            if !PermissionsManager.hasMicrophonePermission() {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Microphone").font(.subheadline)
                        Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                        Spacer()
                        Button("Open Preferences") {
                            // macOS TCC only registers Macaveli in System
                            // Settings → Microphone AFTER the app calls
                            // requestAccess at least once. Without this call,
                            // clicking the button opens an empty pane (or one
                            // that lists every other app but not Macaveli).
                            // Triggering the request shows the system prompt,
                            // which registers us with TCC; then Settings opens
                            // and the user sees Macaveli with a toggle.
                            PermissionsManager.requestMicrophonePermission { _ in
                                DispatchQueue.main.async {
                                    PermissionsManager.openPreferences(at: .microphone)
                                }
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
