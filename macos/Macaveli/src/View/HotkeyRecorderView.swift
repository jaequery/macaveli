// HotkeyRecorderView.swift
import SwiftUI
import ShortcutRecorder

/// Thin SwiftUI wrapper around `RecorderControl` so a `Shortcut?` binding
/// drives the recorder UI. Used inline in the per-section bindings strips.
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var shortcut: Shortcut?

    func makeNSView(context: Context) -> RecorderControl {
        let recorder = RecorderControl()
        recorder.delegate = context.coordinator
        recorder.allowsModifierFlagsOnlyShortcut = true
        recorder.translatesAutoresizingMaskIntoConstraints = false
        // RecorderControl's intrinsic height (~28pt) is too tall for the
        // dense per-section bindings strip — pin it to match the segmented
        // controls below.
        NSLayoutConstraint.activate([
            recorder.heightAnchor.constraint(equalToConstant: 20),
        ])
        return recorder
    }

    func updateNSView(_ nsView: RecorderControl, context: Context) {
        nsView.objectValue = shortcut
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, RecorderControlDelegate {
        var parent: HotkeyRecorderView
        init(_ parent: HotkeyRecorderView) { self.parent = parent }

        func shortcutRecorderDidEndRecording(_ recorder: RecorderControl) {
            parent.shortcut = recorder.objectValue
        }
    }
}
