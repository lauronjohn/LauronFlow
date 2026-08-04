import SwiftUI

/// Changes apply immediately (no restart needed) via the notifications
/// `AppSettings.recordHotkeyOption`/`undoHotkeyLetter`/`undoHotkeyModifiers`
/// post on write — see AppDelegate's observers.
struct ShortcutsSettingsView: View {
    @State private var recordOption = AppSettings.recordHotkeyOption
    @State private var undoLetter = AppSettings.undoHotkeyLetter
    @State private var undoModifiers = AppSettings.undoHotkeyModifiers

    var body: some View {
        Form {
            Section {
                Picker("Hotkey", selection: $recordOption) {
                    ForEach(ModifierHotkeyOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .onChange(of: recordOption) { _, newValue in
                    AppSettings.recordHotkeyOption = newValue
                }
            } header: {
                Text("Record (Push-to-Talk)")
            } footer: {
                Text("Only modifier-only keys are offered: this hotkey is observed, never swallowed, so a regular key would still get typed into whatever app has focus while held.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Shortcut") {
                    ShortcutChip(text: undoShortcutDisplayName)
                }
                LabeledContent("Modifiers") {
                    HStack(spacing: 14) {
                        Toggle("⌃ Control", isOn: modifierBinding(.control))
                        Toggle("⌥ Option", isOn: modifierBinding(.option))
                        Toggle("⇧ Shift", isOn: modifierBinding(.shift))
                    }
                    .toggleStyle(.checkbox)
                }
                Picker("Key", selection: $undoLetter) {
                    ForEach(UndoHotkeyLetter.allCases) { letter in
                        Text(letter.displayName).tag(letter)
                    }
                }
                .onChange(of: undoLetter) { _, newValue in
                    AppSettings.undoHotkeyLetter = newValue
                }
            } header: {
                Text("Undo Last Dictation")
            } footer: {
                Text("At least one modifier is required. Command isn't offered, since it's very likely already bound to something in the frontmost app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset to Defaults", action: resetToDefaults)
                    .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420)
    }

    private var undoShortcutDisplayName: String {
        var symbols = ""
        if undoModifiers.contains(.control) { symbols += "⌃" }
        if undoModifiers.contains(.option) { symbols += "⌥" }
        if undoModifiers.contains(.shift) { symbols += "⇧" }
        return symbols + undoLetter.displayName
    }

    private func resetToDefaults() {
        recordOption = .default
        undoLetter = .default
        undoModifiers = .default
        AppSettings.recordHotkeyOption = .default
        AppSettings.undoHotkeyLetter = .default
        AppSettings.undoHotkeyModifiers = .default
    }

    private func modifierBinding(_ modifier: UndoHotkeyModifiers) -> Binding<Bool> {
        Binding(
            get: { undoModifiers.contains(modifier) },
            set: { isOn in
                var newModifiers = undoModifiers
                if isOn {
                    newModifiers.insert(modifier)
                } else {
                    newModifiers.remove(modifier)
                }
                guard !newModifiers.isEmpty else { return }
                undoModifiers = newModifiers
                AppSettings.undoHotkeyModifiers = newModifiers
            }
        )
    }
}

private struct ShortcutChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
    }
}
