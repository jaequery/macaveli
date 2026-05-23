import SwiftUI

struct RecordingPreferencesView: View {
    @AppStorage(PreferenceKey.recordingFormat.rawValue) private var format = RecordingFormat.mp4.rawValue
    @AppStorage(PreferenceKey.recordingSaveFolder.rawValue) private var saveFolder = ""
    @AppStorage(PreferenceKey.recordingGifMaxSeconds.rawValue) private var gifMaxSeconds = 30
    @AppStorage(PreferenceKey.recordingGifMaxHeight.rawValue) private var gifMaxHeight = 720

    private var effectiveSaveFolder: String {
        saveFolder.isEmpty
            ? (FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path ?? "~/Desktop")
            : saveFolder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Screen Recording").font(.headline)

            HStack {
                Text("Format")
                    .frame(width: 80, alignment: .leading)
                Picker("", selection: $format) {
                    ForEach(RecordingFormat.allCases, id: \.rawValue) { f in
                        Text(f.rawValue).tag(f.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            HStack {
                Text("Save to")
                    .frame(width: 80, alignment: .leading)
                Text(effectiveSaveFolder)
                    .truncationMode(.head)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Choose...") {
                    pickFolder()
                }
            }

            if format == RecordingFormat.gif.rawValue {
                HStack {
                    Text("Max seconds")
                        .frame(width: 80, alignment: .leading)
                    TextField("", value: $gifMaxSeconds, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                }

                HStack {
                    Text("Max height")
                        .frame(width: 80, alignment: .leading)
                    TextField("", value: $gifMaxHeight, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Text("px").foregroundStyle(.secondary)
                }
            }
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            saveFolder = url.path
        }
    }
}

#Preview {
    RecordingPreferencesView()
        .frame(width: MAIN_WINDOW_WIDTH)
        .padding()
}
