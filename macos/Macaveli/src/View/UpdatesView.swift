
import SwiftUI
import Sparkle

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckUpdatesButton: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private var label: String?

    init(label: String? = nil) {
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: UpdatesManager.shared.updater)
        if label != nil {
            self.label = label
        }
    }

    var body: some View {
        Button {
            UpdatesManager.shared.checkForUpdates()
        } label: {
            // When a text label is supplied (the in-popover dropdown), render
            // text only. A leading SF Symbol would make the menu item the only
            // imaged row, shifting its text right of the plain-text rows
            // (About, Quit, the toggles) and breaking column alignment.
            // With no label (the app-menu command), keep the icon-only look.
            if let label {
                Text(label)
            } else {
                Image(systemName: "arrow.counterclockwise")
                    .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
            }
        }
    }
}

#Preview {
    CheckUpdatesButton(label: "Check for updates").padding()
}
