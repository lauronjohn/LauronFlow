import Foundation

enum AppSettings {
    // Both default to `true` (on) when unset, preserving existing behavior
    // for users upgrading from a version before these toggles existed.
    static var showRecordingWidget: Bool {
        get { UserDefaults.standard.object(forKey: "showRecordingWidget") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showRecordingWidget") }
    }

    static var vocabularyEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "vocabularyEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "vocabularyEnabled") }
    }

    // Default to the original hardcoded bindings (Right Option / Control+Option+Z)
    // when unset, preserving existing behavior for users upgrading from a version
    // before these were configurable. Setting these posts a notification rather than
    // requiring an app restart — see AppDelegate's observers.
    static var recordHotkeyOption: ModifierHotkeyOption {
        get {
            guard let raw = UserDefaults.standard.object(forKey: "recordHotkeyOption") as? Int,
                  let option = ModifierHotkeyOption(keyCode: raw)
            else { return .default }
            return option
        }
        set {
            UserDefaults.standard.set(newValue.keyCode, forKey: "recordHotkeyOption")
            NotificationCenter.default.post(name: .recordHotkeyChanged, object: nil)
        }
    }

    static var undoHotkeyLetter: UndoHotkeyLetter {
        get {
            guard let raw = UserDefaults.standard.object(forKey: "undoHotkeyLetter") as? Int,
                  let letter = UndoHotkeyLetter(keyCode: raw)
            else { return .default }
            return letter
        }
        set {
            UserDefaults.standard.set(newValue.keyCode, forKey: "undoHotkeyLetter")
            NotificationCenter.default.post(name: .undoHotkeyChanged, object: nil)
        }
    }

    static var undoHotkeyModifiers: UndoHotkeyModifiers {
        get {
            guard let raw = UserDefaults.standard.object(forKey: "undoHotkeyModifiers") as? Int else {
                return .default
            }
            return UndoHotkeyModifiers(rawValue: raw)
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "undoHotkeyModifiers")
            NotificationCenter.default.post(name: .undoHotkeyChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let recordHotkeyChanged = Notification.Name("com.lauronjohn.LauronFlow.recordHotkeyChanged")
    static let undoHotkeyChanged = Notification.Name("com.lauronjohn.LauronFlow.undoHotkeyChanged")
}
