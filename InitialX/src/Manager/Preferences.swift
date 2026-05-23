import Foundation

enum PreferenceKey: String {
    case focusOnApp = "focusOnApp"
    case showMenuBarIcon = "showMenuBarIcon"
    case useQuadrants = "useQuadrants"
    case requireMouseClick = "requireMouseClick"
    case recordingFormat = "recordingFormat"
    case recordingSaveFolder = "recordingSaveFolder"
    case recordingGifMaxSeconds = "recordingGifMaxSeconds"
    case recordingGifMaxHeight = "recordingGifMaxHeight"
}

class PreferencesManager {
    static func loadBool(for key: PreferenceKey) -> Bool {
        return UserDefaults.standard.bool(forKey: key.rawValue)
    }
}
