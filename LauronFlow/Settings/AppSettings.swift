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
}
