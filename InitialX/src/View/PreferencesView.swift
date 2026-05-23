import SwiftUI
import LaunchAtLogin

struct PreferencesView: View {
    @AppStorage(PreferenceKey.showMenuBarIcon.rawValue) var showMenuBarIcon = true
    @AppStorage(PreferenceKey.focusOnApp.rawValue) var focusOnApp = true
    @AppStorage(PreferenceKey.useQuadrants.rawValue) var useQuadrants = false
    @AppStorage(PreferenceKey.requireMouseClick.rawValue) var requireMouseClick = false
    
    var body: some View {
        VStack(alignment: .leading) {

            LaunchAtLogin.Toggle()

            Toggle(isOn: $showMenuBarIcon) {
                Text("Show menu bar icon")
                Text("Open the app again to re-enable the icon")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            RecordingPreferencesView()
        }
    }
}

#Preview {
    PreferencesView()
}
