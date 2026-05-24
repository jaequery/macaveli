import SwiftUI

struct RecordingPreferencesView: View {
    @AppStorage(PreferenceKey.recordingFormat.rawValue) private var format = RecordingFormat.mp4.rawValue
    @AppStorage(PreferenceKey.recordingSaveFolder.rawValue) private var saveFolder = ""
    @AppStorage(PreferenceKey.recordingGifMaxSeconds.rawValue) private var gifMaxSeconds = 30
    @AppStorage(PreferenceKey.recordingGifMaxHeight.rawValue) private var gifMaxHeight = 1080
    @AppStorage(PreferenceKey.recordingGifFps.rawValue) private var gifFps = GifFps.defaultValue.rawValue
    @AppStorage(PreferenceKey.recordingOptimizeMP4.rawValue) private var optimizeMP4 = false
    @AppStorage(PreferenceKey.recordingQuality.rawValue) private var quality = RecordingQuality.defaultValue.rawValue
    @AppStorage(PreferenceKey.recordingFps.rawValue) private var fps = RecordingFps.defaultValue.rawValue
    @AppStorage(PreferenceKey.recordingDemoMode.rawValue) private var demoMode = false
    @AppStorage(PreferenceKey.recordingCountdownSeconds.rawValue) private var countdownSeconds = 3

    private var effectiveSaveFolder: String {
        saveFolder.isEmpty
            ? (FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path ?? "~/Desktop")
            : saveFolder
    }

    private var folderDisplayName: String {
        (effectiveSaveFolder as NSString).abbreviatingWithTildeInPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Screen Recording")

            HStack {
                Text("Format")
                    .frame(width: 90, alignment: .leading)
                    .foregroundStyle(.secondary)
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
                    .frame(width: 90, alignment: .leading)
                    .foregroundStyle(.secondary)
                Text(folderDisplayName)
                    .truncationMode(.head)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Choose…") { pickFolder() }
                    .controlSize(.small)
            }

            if format == RecordingFormat.mp4.rawValue {
                mp4QualityControls
            } else {
                gifQualityControls
            }

            // Demo mode applies to both formats — surface it under either.
            Toggle(isOn: $demoMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Demo mode")
                    Text("Auto-zooms toward the cursor for a product-demo feel. Slower export.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Countdown")
                    .frame(width: 90, alignment: .leading)
                    .foregroundStyle(.secondary)
                Picker("", selection: $countdownSeconds) {
                    Text("Off").tag(0)
                    Text("3 s").tag(3)
                    Text("5 s").tag(5)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
                Spacer()
            }
        }
    }

    // MARK: - MP4

    @ViewBuilder private var mp4QualityControls: some View {
        HStack(alignment: .top) {
            Text("Quality")
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Picker("", selection: $quality) {
                    ForEach(RecordingQuality.allCases, id: \.rawValue) { q in
                        Text(q.rawValue).tag(q.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(qualityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        HStack {
            Text("Frame rate")
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(.secondary)
            Picker("", selection: $fps) {
                ForEach(RecordingFps.allCases, id: \.rawValue) { f in
                    Text(f.label).tag(f.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 140)
            Spacer()
        }

        Toggle(isOn: $optimizeMP4) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Optimize for sharing")
                Text("Re-encode to 1080p H.264 after recording. Slower, smaller file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var qualityDescription: String {
        (RecordingQuality(rawValue: quality) ?? .defaultValue).description
    }

    // MARK: - GIF

    @ViewBuilder private var gifQualityControls: some View {
        HStack(alignment: .top) {
            Text("Frame rate")
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Picker("", selection: $gifFps) {
                    ForEach(GifFps.allCases, id: \.rawValue) { f in
                        Text(f.label).tag(f.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("Higher fps = smoother motion, bigger file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        HStack {
            Text("Max height")
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(.secondary)
            TextField("", value: $gifMaxHeight, formatter: NumberFormatter())
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
            Text("px").foregroundStyle(.secondary)
            Spacer()
        }

        HStack {
            Text("Max seconds")
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(.secondary)
            TextField("", value: $gifMaxSeconds, formatter: NumberFormatter())
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
            Spacer()
        }

        Text("GIF uses a 256-color palette — for sharper colors, use MP4.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
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
