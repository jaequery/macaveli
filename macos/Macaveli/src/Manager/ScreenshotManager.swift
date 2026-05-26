import AppKit

/// Runs macOS's native interactive `screencapture` and confirms clipboard success.
final class ScreenshotManager {
    static let shared = ScreenshotManager()

    private let captureQueue = DispatchQueue(label: "com.macaveli.screenshot", qos: .userInitiated)
    private var isCapturing = false

    private init() {}

    func captureInteractiveToClipboard() {
        guard !isCapturing else { return }
        isCapturing = true

        captureQueue.async { [weak self] in
            defer { self?.isCapturing = false }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-c"]

            do {
                try process.run()
            } catch {
                return
            }

            process.waitUntilExit()
            guard process.terminationStatus == 0, Self.pasteboardHasImage() else { return }

            DispatchQueue.main.async {
                ScreenshotConfirmationOverlay.shared.show()
            }
        }
    }

    private static func pasteboardHasImage() -> Bool {
        let pb = NSPasteboard.general
        if pb.canReadObject(forClasses: [NSImage.self], options: nil) {
            return true
        }
        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
        return imageTypes.contains { pb.availableType(from: imageTypes) == $0 }
    }
}
