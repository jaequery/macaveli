import Foundation

enum PreferenceKey: String {
    case focusOnApp = "focusOnApp"
    case showMenuBarIcon = "showMenuBarIcon"
    case useQuadrants = "useQuadrants"
    case recordingFormat = "recordingFormat"
    case recordingSaveFolder = "recordingSaveFolder"
    case recordingGifMaxSeconds = "recordingGifMaxSeconds"
    case recordingGifMaxHeight = "recordingGifMaxHeight"
    case recordingOptimizeMP4 = "recordingOptimizeMP4"
    case recordingQuality = "recordingQuality"
    case recordingFps = "recordingFps"
    case recordingGifFps = "recordingGifFps"
    case recordingDemoMode = "recordingDemoMode"
    case recordingCountdownSeconds = "recordingCountdownSeconds"
    case pasteHistorySize = "pasteHistorySize"
    case keepDisplayAwakeOnLidClose = "keepDisplayAwakeOnLidClose"
}

class PreferencesManager {
    static func loadBool(for key: PreferenceKey) -> Bool {
        return UserDefaults.standard.bool(forKey: key.rawValue)
    }
}

/// MP4 quality preset. Controls the H.264 bitrate-per-pixel target.
enum RecordingQuality: String, CaseIterable {
    case standard = "Standard"
    case high = "High"
    case maximum = "Maximum"

    /// Bits-per-pixel-per-second target. 0.15 ≈ good for sharing, 0.40 ≈ sharp
    /// text/UI, 0.80 ≈ near-lossless for archival.
    var bitsPerPixelPerSecond: Double {
        switch self {
        case .standard: return 0.15
        case .high:     return 0.40
        case .maximum:  return 0.80
        }
    }

    var description: String {
        switch self {
        case .standard: return "Smaller file, good for sharing."
        case .high:     return "Sharp text and UI. Recommended."
        case .maximum:  return "Near-lossless. Large files."
        }
    }

    static var defaultValue: RecordingQuality { .high }
}

enum RecordingFps: Int, CaseIterable {
    case fps30 = 30
    case fps60 = 60

    var label: String { "\(rawValue) fps" }

    static var defaultValue: RecordingFps { .fps30 }
}

enum GifFps: Int, CaseIterable {
    case fps10 = 10
    case fps15 = 15
    case fps24 = 24
    case fps30 = 30

    var label: String { "\(rawValue)" }

    static var defaultValue: GifFps { .fps15 }
}
