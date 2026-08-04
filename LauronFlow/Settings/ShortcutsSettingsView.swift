import SwiftUI

/// Static reference list — these key combos are hardcoded where they're
/// actually handled (`HotkeyManager`'s `kVK_RightOption` check,
/// `UndoHotkeyManager`'s Control+Option+Z check), not read from a shared
/// source of truth. Keep this list in sync by hand if either changes.
struct ShortcutsSettingsView: View {
    private let shortcuts: [(action: String, keys: String)] = [
        ("Record (push-to-talk)", "Hold Right ⌥ Option"),
        ("Undo last dictation", "⌃ Control + ⌥ Option + Z"),
    ]

    var body: some View {
        Form {
            ForEach(shortcuts, id: \.action) { shortcut in
                LabeledContent(shortcut.action) {
                    Text(shortcut.keys)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}
