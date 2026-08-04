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
            Section("Record (push-to-talk)") {
                Picker("Hold to record", selection: $recordOption) {
                    ForEach(ModifierHotkeyOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .onChange(of: recordOption) { _, newValue in
                    AppSettings.recordHotkeyOption = newValue
                }
                Text("Only modifier-only keys are offered: this hotkey is observed, never swallowed, so a regular key would still get typed into whatever app has focus while held.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Undo last dictation") {
                HStack {
                    Toggle("⌃ Control", isOn: modifierBinding(.control))
                    Toggle("⌥ Option", isOn: modifierBinding(.option))
                    Toggle("⇧ Shift", isOn: modifierBinding(.shift))
                }
                Picker("Key", selection: $undoLetter) {
                    ForEach(UndoHotkeyLetter.allCases) { letter in
                        Text(letter.displayName).tag(letter)
                    }
                }
                .onChange(of: undoLetter) { _, newValue in
                    AppSettings.undoHotkeyLetter = newValue
                }
                Text("At least one modifier is required. Command isn't offered, since it's very likely already bound to something in the frontmost app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Reset to Defaults") {
                recordOption = .default
                undoLetter = .default
                undoModifiers = .default
                AppSettings.recordHotkeyOption = .default
                AppSettings.undoHotkeyLetter = .default
                AppSettings.undoHotkeyModifiers = .default
            }
        }
        .padding()
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
