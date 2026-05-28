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
    case recordingCameraOverlay = "recordingCameraOverlay"
    case recordingCameraX = "recordingCameraX"
    case recordingCameraY = "recordingCameraY"
    case pasteHistorySize = "pasteHistorySize"
    case neverSleepMode = "neverSleepMode"
}

/// Camera overlay geometry shared by the on-screen positioning bubble and the
/// recorder's compositor. Coordinates are a normalized **center** (top-left
/// origin, 0…1) so they survive resolution changes and map cleanly onto the
/// recorded video's pixel space.
enum CameraOverlayDefaults {
    /// Default center — bottom-right, with margin for the bubble radius.
    static let centerX: Double = 0.82
    static let centerY: Double = 0.82
    /// Bubble diameter as a fraction of the shorter canvas dimension.
    static let diameterFraction: Double = 0.20

    /// Reads the persisted center, falling back to the bottom-right default
    /// when the keys were never set (UserDefaults returns 0 for an absent
    /// Double, which would otherwise pin the bubble to the top-left corner).
    static func center() -> (x: Double, y: Double) {
        let d = UserDefaults.standard
        let x = d.object(forKey: PreferenceKey.recordingCameraX.rawValue) as? Double ?? centerX
        let y = d.object(forKey: PreferenceKey.recordingCameraY.rawValue) as? Double ?? centerY
        return (x, y)
    }

    static func setCenter(x: Double, y: Double) {
        let d = UserDefaults.standard
        d.set(min(1, max(0, x)), forKey: PreferenceKey.recordingCameraX.rawValue)
        d.set(min(1, max(0, y)), forKey: PreferenceKey.recordingCameraY.rawValue)
    }
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
