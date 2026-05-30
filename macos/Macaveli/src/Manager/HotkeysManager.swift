import ShortcutRecorder
import CGEventSupervisor

enum HotkeyType: String, CaseIterable {
    case move = "Move"
    case resize = "Resize"
    case maximize = "Maximize"
    case center = "Center"
    case leftHalf = "Left Half"
    case rightHalf = "Right Half"
    case record = "Record"
    case annotate = "Annotate"
    case paste = "Paste"
    case screenshot = "Screenshot"

    var isMouseDriven: Bool {
        switch self {
        case .move, .resize: return true
        case .maximize, .center, .leftHalf, .rightHalf, .record, .annotate, .paste, .screenshot: return false
        }
    }
}

enum MouseButton: String, CaseIterable {
    case none = "None"
    case left = "Left"
    case right = "Right"

    static func parse(rawValue: String?) -> MouseButton {
      guard let rawValue = rawValue else { return .none }
      if let value = MouseButton(rawValue: rawValue) {
        return value
      } else {
        return .none
      }
    }
}

struct UserHotkey {
    var type: HotkeyType
    var shortcut: Shortcut?
    var mouseButton: MouseButton

    init(type: HotkeyType, shortcut: Shortcut? = nil, mouseButton: MouseButton) {
        self.type = type
        self.shortcut = shortcut
        self.mouseButton = mouseButton
    }
}

class HotkeysManager {
    static let shared = HotkeysManager()
    var globalMonitors: [Any] = []

    private init() {
        seedDefaultHotkeysIfNeeded()
        migrateClickModeIfNeeded()
        updateGlobalHotkeys()
    }

    /// One-shot migration for users who had the "Require click" preference on:
    /// wipe any stored per-hotkey mouseButton so the click-handling code
    /// path stays dormant now that the toggle is gone.
    private func migrateClickModeIfNeeded() {
        let key = "didMigrateClickModeRemoval"
        if UserDefaults.standard.bool(forKey: key) { return }
        removeClickActionsForAll()
        UserDefaults.standard.removeObject(forKey: "requireMouseClick")
        UserDefaults.standard.set(true, forKey: key)
    }

    private func seedDefaultHotkeysIfNeeded() {
        let didSeedKey = "didSeedWindowManagementDefaults"
        if !UserDefaults.standard.bool(forKey: didSeedKey) {
            let modifiers: NSEvent.ModifierFlags = [.command, .control]

            if load(for: .maximize) == nil {
                let shortcut = Shortcut(code: .upArrow, modifierFlags: modifiers, characters: nil, charactersIgnoringModifiers: nil)
                save(UserHotkey(type: .maximize, shortcut: shortcut, mouseButton: .none))
            }
            if load(for: .center) == nil {
                let shortcut = Shortcut(code: .downArrow, modifierFlags: modifiers, characters: nil, charactersIgnoringModifiers: nil)
                save(UserHotkey(type: .center, shortcut: shortcut, mouseButton: .none))
            }

            UserDefaults.standard.set(true, forKey: didSeedKey)
        }

        seedMouseHotkeysIfNeeded()
        seedRecordHotkeyIfNeeded()
        seedHalfHotkeysIfNeeded()
        seedAnnotateHotkeyIfNeeded()
        seedPasteHotkeyIfNeeded()
        seedScreenshotHotkeyIfNeeded()
    }

    private func seedHalfHotkeysIfNeeded() {
        let didSeedKey = "didSeedHalfShortcuts"
        if UserDefaults.standard.bool(forKey: didSeedKey) { return }

        let modifiers: NSEvent.ModifierFlags = [.control]
        if load(for: .leftHalf) == nil {
            let shortcut = Shortcut(code: .ansiLeftBracket, modifierFlags: modifiers, characters: nil, charactersIgnoringModifiers: nil)
            save(UserHotkey(type: .leftHalf, shortcut: shortcut, mouseButton: .none))
        }
        if load(for: .rightHalf) == nil {
            let shortcut = Shortcut(code: .ansiRightBracket, modifierFlags: modifiers, characters: nil, charactersIgnoringModifiers: nil)
            save(UserHotkey(type: .rightHalf, shortcut: shortcut, mouseButton: .none))
        }

        UserDefaults.standard.set(true, forKey: didSeedKey)
    }

    private func seedMouseHotkeysIfNeeded() {
        let didSeedKey = "didSeedMouseShortcuts"
        if UserDefaults.standard.bool(forKey: didSeedKey) { return }

        if load(for: .move) == nil {
            let shortcut = Shortcut(code: .none, modifierFlags: [.command, .control], characters: nil, charactersIgnoringModifiers: nil)
            save(UserHotkey(type: .move, shortcut: shortcut, mouseButton: .none))
        }
        if load(for: .resize) == nil {
            let shortcut = Shortcut(code: .none, modifierFlags: [.command, .shift], characters: nil, charactersIgnoringModifiers: nil)
            save(UserHotkey(type: .resize, shortcut: shortcut, mouseButton: .none))
        }

        UserDefaults.standard.set(true, forKey: didSeedKey)
    }

    private func seedRecordHotkeyIfNeeded() {
        let didSeedKey = "didSeedRecordShortcut"
        if UserDefaults.standard.bool(forKey: didSeedKey) { return }

        if load(for: .record) == nil {
            let modifiers: NSEvent.ModifierFlags = [.command, .control]
            let shortcut = Shortcut(code: .ansiR, modifierFlags: modifiers, characters: nil, charactersIgnoringModifiers: nil)
            save(UserHotkey(type: .record, shortcut: shortcut, mouseButton: .none))
        }

        UserDefaults.standard.set(true, forKey: didSeedKey)
    }

    private func seedAnnotateHotkeyIfNeeded() {
        let didSeedKey = "didSeedAnnotateShortcut"
        if UserDefaults.standard.bool(forKey: didSeedKey) { return }

        if load(for: .annotate) == nil {
            let modifiers: NSEvent.ModifierFlags = [.command, .control]
            let shortcut = Shortcut(code: .ansiA, modifierFlags: modifiers, characters: nil, charactersIgnoringModifiers: nil)
            save(UserHotkey(type: .annotate, shortcut: shortcut, mouseButton: .none))
        }

        UserDefaults.standard.set(true, forKey: didSeedKey)
    }

    private func seedPasteHotkeyIfNeeded() {
        let didSeedKey = "didSeedPasteShortcut"
        if UserDefaults.standard.bool(forKey: didSeedKey) { return }

        if load(for: .paste) == nil {
            let modifiers: NSEvent.ModifierFlags = [.command, .control]
            let shortcut = Shortcut(code: .ansiP, modifierFlags: modifiers, characters: nil, charactersIgnoringModifiers: nil)
            save(UserHotkey(type: .paste, shortcut: shortcut, mouseButton: .none))
        }

        UserDefaults.standard.set(true, forKey: didSeedKey)
    }

    private func seedScreenshotHotkeyIfNeeded() {
        let didSeedKey = "didSeedScreenshotShortcut"
        if UserDefaults.standard.bool(forKey: didSeedKey) { return }

        if load(for: .screenshot) == nil {
            let modifiers: NSEvent.ModifierFlags = [.command, .control]
            let shortcut = Shortcut(code: .ansi4, modifierFlags: modifiers, characters: nil, charactersIgnoringModifiers: nil)
            save(UserHotkey(type: .screenshot, shortcut: shortcut, mouseButton: .none))
        }

        UserDefaults.standard.set(true, forKey: didSeedKey)
    }

    func save(_ userHotkey: UserHotkey) {
        do {
            if let shortcut = userHotkey.shortcut {
                let data = try NSKeyedArchiver.archivedData(withRootObject: shortcut, requiringSecureCoding: false)
                UserDefaults.standard.set(data, forKey: userHotkey.type.rawValue)
                UserDefaults.standard.set(userHotkey.mouseButton.rawValue, forKey: "\(userHotkey.type.rawValue)_mouseButton")
            }
        } catch {
            print("Error: \(error)")
        }
        updateGlobalHotkeys()
    }

    func load(for type: HotkeyType) -> UserHotkey? {
        guard let data = UserDefaults.standard.data(forKey: type.rawValue) else { return nil }
        do {
            let shortcut = try NSKeyedUnarchiver.unarchivedObject(ofClass: Shortcut.self, from: data)
            let mouseButton = MouseButton.parse(rawValue: UserDefaults.standard.string(forKey: "\(type.rawValue)_mouseButton"))
            return UserHotkey(type: type, shortcut: shortcut, mouseButton: mouseButton)
        } catch {
            print("Error unarchiving data: \(error.localizedDescription)")
            return nil
        }
    }

    func delete(for type: HotkeyType) {
        UserDefaults.standard.removeObject(forKey: type.rawValue)
        updateGlobalHotkeys()
    }

    func removeClickActionsForAll() {
        for type in HotkeyType.allCases {
            if var userHotkey = load(for: type) {
                userHotkey.mouseButton = .none
                self.save(userHotkey)
            }
        }
    }

    private func clearActionsAndMonitors() {
        removeAllActions()
        removeGlobalMonitors()
    }

    private func removeAllActions() {
        AppDelegate.shared.hotkeyMonitor?.removeAllActions()
    }

    private func removeGlobalMonitors() {
        for monitor in self.globalMonitors {
            NSEvent.removeMonitor(monitor)
        }
        self.globalMonitors = []
    }

    // Regular hotkeys that should work fine except for modifier-only hotkeys on key-up
    private func addActions(mouseAction: MouseAction, for userHotkey: UserHotkey) {
        guard let shortcut = userHotkey.shortcut else { return }

        let keydownAction = ShortcutAction(shortcut: shortcut) { _ in
            self.startTracking(userHotkey, mouseAction)
            return true
        }
        let keyupAction = ShortcutAction(shortcut: shortcut) { _ in
            self.stopTracking(userHotkey, mouseAction)
            return true
        }

        AppDelegate.shared.hotkeyMonitor?.addAction(keydownAction, forKeyEvent: .down)
        AppDelegate.shared.hotkeyMonitor?.addAction(keyupAction, forKeyEvent: .up)
    }

    // Workaround to get those f**kers to work on key-up
    private func addGlobalMonitors(mouseAction: MouseAction, for userHotkey: UserHotkey) {
        guard let shortcut = userHotkey.shortcut else { return }

        // Global events
        if let eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp, .keyDown, .flagsChanged], handler: { (event) in
            self.handleFlagsChanged(userHotkey, shortcut, event, mouseAction)
        }) {
            self.globalMonitors.append(eventMonitor)
        }
        // Local events (https://github.com/jaequery/Macaveli/issues/10#issuecomment-1872524489)
        if let eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyUp, .keyDown, .flagsChanged], handler: {(event) in
            self.handleFlagsChanged(userHotkey, shortcut, event, mouseAction)
            return event
        }) {
            self.globalMonitors.append(eventMonitor)
        }
    }

    private func updateGlobalHotkeys() {
        clearActionsAndMonitors()

        for type in HotkeyType.allCases {
            if let userHotkey = load(for: type), let shortcut = userHotkey.shortcut {
                if !type.isMouseDriven {
                    addOneShotAction(for: userHotkey)
                    continue
                }

                let mouseAction: MouseAction = type == .move ? .move : .resize
                let isModifierOnlyShortcut = shortcut.charactersIgnoringModifiers == nil

                if isModifierOnlyShortcut {
                    addGlobalMonitors(mouseAction: mouseAction, for: userHotkey)
                } else {
                    addActions(mouseAction: mouseAction, for: userHotkey)
                }
            }
        }
    }

    private func addOneShotAction(for userHotkey: UserHotkey) {
        guard let shortcut = userHotkey.shortcut else { return }
        let type = userHotkey.type

        let action = ShortcutAction(shortcut: shortcut) { _ in
            DispatchQueue.main.async {
                // Kill any in-flight modifier-only tracker first — the user's
                // modifiers (e.g. ⌃⌘) likely already started .move tracking,
                // and we don't want a stray mouse-jitter to undo this action.
                MouseTracker.shared.forceStopTracking()

                switch type {
                case .maximize: WindowActions.maximize()
                case .center: WindowActions.center()
                case .leftHalf: WindowActions.leftHalf()
                case .rightHalf: WindowActions.rightHalf()
                case .record: ScreenRecorder.shared.toggle()
                case .annotate: AnnotatorManager.shared.openFromClipboard()
                case .paste: PasteManager.shared.togglePanel()
                case .screenshot: ScreenshotManager.shared.captureInteractiveToClipboard()
                case .move, .resize: break
                }
            }
            return true
        }
        AppDelegate.shared.hotkeyMonitor?.addAction(action, forKeyEvent: .down)
    }

    private func handleFlagsChanged(_ userHotkey: UserHotkey, _ shortcut: Shortcut, _ event: NSEvent, _ action: MouseAction) {
        let eventFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Sometimes the tracking doesn't stop, so we force it to stop in every flag change
        stopTracking(userHotkey, action)

        if eventFlags == shortcut.modifierFlags {
            startTracking(userHotkey, action)
        }
    }

    private func startTracking(_ userHotkey: UserHotkey, _ action: MouseAction) {
        if userHotkey.mouseButton == .none {
            MouseTracker.shared.startTracking(for: action, button: .none)
            return
        }

        let downEvent: CGEventType = userHotkey.mouseButton == .left ? .leftMouseDown : .rightMouseDown
        let upEvent: CGEventType = userHotkey.mouseButton == .left ? .leftMouseUp : .rightMouseUp

        CGEventSupervisor.shared.subscribe(
            as: "\(action.rawValue)_mouseDown",
            to: .cgEvents(downEvent),
            using: {(event) in
                event.cancel()
                MouseTracker.shared.startTracking(for: action, button: userHotkey.mouseButton)
            });

        CGEventSupervisor.shared.subscribe(
            as: "\(action.rawValue)_mouseUp",
            to: .cgEvents(upEvent),
            using: {(event) in
                event.cancel()
                MouseTracker.shared.stopTracking(for: action)
            });
    }

    private func stopTracking(_ userHotkey: UserHotkey, _ action: MouseAction) {
        MouseTracker.shared.stopTracking(for: action)
        CGEventSupervisor.shared.cancel(subscriber: "\(action.rawValue)_mouseDown")
        CGEventSupervisor.shared.cancel(subscriber: "\(action.rawValue)_mouseUp")
    }
}
