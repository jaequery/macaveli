import ShortcutRecorder
import CGEventSupervisor

enum ShortcutType: String, CaseIterable {
    case move = "Move"
    case resize = "Resize"
    case maximize = "Maximize"
    case center = "Center"
    case leftHalf = "Left Half"
    case rightHalf = "Right Half"
    case record = "Record"

    var isMouseDriven: Bool {
        switch self {
        case .move, .resize: return true
        case .maximize, .center, .leftHalf, .rightHalf, .record: return false
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

struct UserShortcut {
    var type: ShortcutType
    var shortcut: Shortcut?
    var mouseButton: MouseButton
    
    init(type: ShortcutType, shortcut: Shortcut? = nil, mouseButton: MouseButton) {
        self.type = type
        self.shortcut = shortcut
        self.mouseButton = mouseButton
    }
}

class ShortcutsManager {
    static let shared = ShortcutsManager()
    var globalMonitors: [Any] = []
    
    private init() {
        seedDefaultShortcutsIfNeeded()
        migrateClickModeIfNeeded()
        updateGlobalShortcuts()
    }

    /// One-shot migration for users who had the "Require click" preference on:
    /// wipe any stored per-shortcut mouseButton so the click-handling code
    /// path stays dormant now that the toggle is gone.
    private func migrateClickModeIfNeeded() {
        let key = "didMigrateClickModeRemoval"
        if UserDefaults.standard.bool(forKey: key) { return }
        removeClickActionsForAll()
        UserDefaults.standard.removeObject(forKey: "requireMouseClick")
        UserDefaults.standard.set(true, forKey: key)
    }

    private func seedDefaultShortcutsIfNeeded() {
        let didSeedKey = "didSeedWindowManagementDefaults"
        if !UserDefaults.standard.bool(forKey: didSeedKey) {
            let modifiers: NSEvent.ModifierFlags = [.command, .control]

            if load(for: .maximize) == nil {
                let shortcut = Shortcut(code: .upArrow, modifierFlags: modifiers, characters: nil, charactersIgnoringModifiers: nil)
                save(UserShortcut(type: .maximize, shortcut: shortcut, mouseButton: .none))
            }
            if load(for: .center) == nil {
                let shortcut = Shortcut(code: .downArrow, modifierFlags: modifiers, characters: nil, charactersIgnoringModifiers: nil)
                save(UserShortcut(type: .center, shortcut: shortcut, mouseButton: .none))
            }

            UserDefaults.standard.set(true, forKey: didSeedKey)
        }

        seedMouseShortcutsIfNeeded()
        seedRecordShortcutIfNeeded()
        seedHalfShortcutsIfNeeded()
    }

    private func seedHalfShortcutsIfNeeded() {
        let didSeedKey = "didSeedHalfShortcuts"
        if UserDefaults.standard.bool(forKey: didSeedKey) { return }

        let modifiers: NSEvent.ModifierFlags = [.control]
        if load(for: .leftHalf) == nil {
            let shortcut = Shortcut(code: .ansiLeftBracket, modifierFlags: modifiers, characters: nil, charactersIgnoringModifiers: nil)
            save(UserShortcut(type: .leftHalf, shortcut: shortcut, mouseButton: .none))
        }
        if load(for: .rightHalf) == nil {
            let shortcut = Shortcut(code: .ansiRightBracket, modifierFlags: modifiers, characters: nil, charactersIgnoringModifiers: nil)
            save(UserShortcut(type: .rightHalf, shortcut: shortcut, mouseButton: .none))
        }

        UserDefaults.standard.set(true, forKey: didSeedKey)
    }

    private func seedMouseShortcutsIfNeeded() {
        let didSeedKey = "didSeedMouseShortcuts"
        if UserDefaults.standard.bool(forKey: didSeedKey) { return }

        if load(for: .move) == nil {
            let shortcut = Shortcut(code: .none, modifierFlags: [.command, .control], characters: nil, charactersIgnoringModifiers: nil)
            save(UserShortcut(type: .move, shortcut: shortcut, mouseButton: .none))
        }
        if load(for: .resize) == nil {
            let shortcut = Shortcut(code: .none, modifierFlags: [.command, .shift], characters: nil, charactersIgnoringModifiers: nil)
            save(UserShortcut(type: .resize, shortcut: shortcut, mouseButton: .none))
        }

        UserDefaults.standard.set(true, forKey: didSeedKey)
    }

    private func seedRecordShortcutIfNeeded() {
        let didSeedKey = "didSeedRecordShortcut"
        if UserDefaults.standard.bool(forKey: didSeedKey) { return }

        if load(for: .record) == nil {
            let modifiers: NSEvent.ModifierFlags = [.command, .control]
            let shortcut = Shortcut(code: .ansiR, modifierFlags: modifiers, characters: nil, charactersIgnoringModifiers: nil)
            save(UserShortcut(type: .record, shortcut: shortcut, mouseButton: .none))
        }

        UserDefaults.standard.set(true, forKey: didSeedKey)
    }
    
    func save(_ userShortcut: UserShortcut) {
        do {
            if let shortcut = userShortcut.shortcut {
                let data = try NSKeyedArchiver.archivedData(withRootObject: shortcut, requiringSecureCoding: false)
                UserDefaults.standard.set(data, forKey: userShortcut.type.rawValue)
                UserDefaults.standard.set(userShortcut.mouseButton.rawValue, forKey: "\(userShortcut.type.rawValue)_mouseButton")
            }
        } catch {
            print("Error: \(error)")
        }
        updateGlobalShortcuts()
    }
    
    func load(for type: ShortcutType) -> UserShortcut? {
        guard let data = UserDefaults.standard.data(forKey: type.rawValue) else { return nil }
        do {
            let shortcut = try NSKeyedUnarchiver.unarchivedObject(ofClass: Shortcut.self, from: data)
            let mouseButton = MouseButton.parse(rawValue: UserDefaults.standard.string(forKey: "\(type.rawValue)_mouseButton"))
            return UserShortcut(type: type, shortcut: shortcut, mouseButton: mouseButton)
        } catch {
            print("Error unarchiving data: \(error.localizedDescription)")
            return nil
        }
    }
    
    func delete(for type: ShortcutType) {
        UserDefaults.standard.removeObject(forKey: type.rawValue)
        updateGlobalShortcuts()
    }
    
    func removeClickActionsForAll() {
        for type in ShortcutType.allCases {
            if var userShortcut = load(for: type) {
                userShortcut.mouseButton = .none
                self.save(userShortcut)
            }
        }
    }
    
    private func clearActionsAndMonitors() {
        removeAllActions()
        removeGlobalMonitors()
    }
    
    private func removeAllActions() {
        AppDelegate.shared.shortcutMonitor?.removeAllActions()
    }
    
    private func removeGlobalMonitors() {
        for monitor in self.globalMonitors {
            NSEvent.removeMonitor(monitor)
        }
        self.globalMonitors = []
    }
    
    // Regular shortcuts that should work fine except for modifier-only shortcuts on key-up
    private func addActions(mouseAction: MouseAction, for userShortcut: UserShortcut) {
        guard let shortcut = userShortcut.shortcut else { return }

        let keydownAction = ShortcutAction(shortcut: shortcut) { _ in
            self.startTracking(userShortcut, mouseAction)
            return true
        }
        let keyupAction = ShortcutAction(shortcut: shortcut) { _ in
            self.stopTracking(userShortcut, mouseAction)
            return true
        }
        
        AppDelegate.shared.shortcutMonitor?.addAction(keydownAction, forKeyEvent: .down)
        AppDelegate.shared.shortcutMonitor?.addAction(keyupAction, forKeyEvent: .up)
    }
    
    // Workaround to get those f**kers to work on key-up
    private func addGlobalMonitors(mouseAction: MouseAction, for userShortcut: UserShortcut) {
        guard let shortcut = userShortcut.shortcut else { return }

        // Global events
        if let eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp, .keyDown, .flagsChanged], handler: { (event) in
            self.handleFlagsChanged(userShortcut, shortcut, event, mouseAction)
        }) {
            self.globalMonitors.append(eventMonitor)
        }
        // Local events (https://github.com/jaequery/Macaveli/issues/10#issuecomment-1872524489)
        if let eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyUp, .keyDown, .flagsChanged], handler: {(event) in
            self.handleFlagsChanged(userShortcut, shortcut, event, mouseAction)
            return event
        }) {
            self.globalMonitors.append(eventMonitor)
        }
    }
    
    private func updateGlobalShortcuts() {
        clearActionsAndMonitors()

        for type in ShortcutType.allCases {
            if let userShortcut = load(for: type), let shortcut = userShortcut.shortcut {
                if !type.isMouseDriven {
                    addOneShotAction(for: userShortcut)
                    continue
                }

                let mouseAction: MouseAction = type == .move ? .move : .resize
                let isModifierOnlyShortcut = shortcut.charactersIgnoringModifiers == nil

                if isModifierOnlyShortcut {
                    addGlobalMonitors(mouseAction: mouseAction, for: userShortcut)
                } else {
                    addActions(mouseAction: mouseAction, for: userShortcut)
                }
            }
        }
    }

    private func addOneShotAction(for userShortcut: UserShortcut) {
        guard let shortcut = userShortcut.shortcut else { return }
        let type = userShortcut.type

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
                case .move, .resize: break
                }
            }
            return true
        }
        AppDelegate.shared.shortcutMonitor?.addAction(action, forKeyEvent: .down)
    }
    
    private func handleFlagsChanged(_ userShortcut: UserShortcut, _ shortcut: Shortcut, _ event: NSEvent, _ action: MouseAction) {
        let eventFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        // Sometimes the tracking doesn't stop, so we force it to stop in every flag change
        stopTracking(userShortcut, action)

        if eventFlags == shortcut.modifierFlags {
            startTracking(userShortcut, action)
        }
    }

    private func startTracking(_ userShortcut: UserShortcut, _ action: MouseAction) {
        if userShortcut.mouseButton == .none {
            MouseTracker.shared.startTracking(for: action, button: .none)
            return
        }

        let downEvent: CGEventType = userShortcut.mouseButton == .left ? .leftMouseDown : .rightMouseDown
        let upEvent: CGEventType = userShortcut.mouseButton == .left ? .leftMouseUp : .rightMouseUp

        CGEventSupervisor.shared.subscribe(
            as: "\(action.rawValue)_mouseDown",
            to: .cgEvents(downEvent),
            using: {(event) in
                event.cancel()
                MouseTracker.shared.startTracking(for: action, button: userShortcut.mouseButton)
            });

        CGEventSupervisor.shared.subscribe(
            as: "\(action.rawValue)_mouseUp",
            to: .cgEvents(upEvent),
            using: {(event) in
                event.cancel()
                MouseTracker.shared.stopTracking(for: action)
            });
    }

    private func stopTracking(_ userShortcut: UserShortcut, _ action: MouseAction) {
        MouseTracker.shared.stopTracking(for: action)
        CGEventSupervisor.shared.cancel(subscriber: "\(action.rawValue)_mouseDown")
        CGEventSupervisor.shared.cancel(subscriber: "\(action.rawValue)_mouseUp")
    }
}
