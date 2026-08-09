import Foundation

/// Whether the push-to-talk hotkey is held for the duration of a recording, or
/// tapped once to start and again to stop. Read fresh at each hotkey event in
/// `AppDelegate` rather than cached, so no change notification is needed here.
enum RecordingMode: String {
    case hold, toggle

    static let `default`: RecordingMode = .hold
}

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

    static var recordingMode: RecordingMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "recordingMode"),
                  let mode = RecordingMode(rawValue: raw)
            else { return .default }
            return mode
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "recordingMode") }
    }

    /// Bundle identifiers of apps the floating recording widget should never show
    /// in, even when `showRecordingWidget` is on — e.g. apps where a floating
    /// overlay would be distracting or visually clash (full-screen video, games).
    static var excludedApps: [String] {
        get { UserDefaults.standard.stringArray(forKey: "excludedApps") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "excludedApps") }
    }

    /// Gates the blocking onboarding window — shown once, and again on any later
    /// launch if the user quit before finishing it. `AppDelegate` grandfathers in
    /// upgraders from a pre-onboarding version using `hasOnboardingPreferenceStored`
    /// below, so this defaulting to `false` doesn't show it to them retroactively.
    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    /// Whether `hasCompletedOnboarding` has ever been explicitly written, as opposed
    /// to just reading `false` because the key was never set. Distinguishing these
    /// is what lets `AppDelegate` tell "brand new install" apart from "existing
    /// install from before onboarding existed" on the first launch after upgrading.
    static var hasOnboardingPreferenceStored: Bool {
        UserDefaults.standard.object(forKey: "hasCompletedOnboarding") != nil
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
