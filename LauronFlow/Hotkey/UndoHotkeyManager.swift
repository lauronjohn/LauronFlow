import AppKit
import Carbon.HIToolbox

/// Global hotkey for "undo last dictation": a configurable letter plus
/// Control/Option/Shift modifiers (default: Control+Option+Z — see
/// `UndoHotkeyLetter`/`UndoHotkeyModifiers`).
///
/// Command is deliberately never offered as a modifier — a global `NSEvent`
/// monitor can only observe events, never consume them, so binding to a shortcut
/// a target app (or macOS itself) already handles natively would cause a
/// double-delete. The default, Control+Option+Z, isn't a default Cocoa or system
/// binding; the one accepted caveat (same spirit as `HotkeyManager`'s physical-key
/// note) is that Control+Option is macOS's VoiceOver modifier pair, so this could
/// collide with a VoiceOver command if VoiceOver is enabled — acceptable for a
/// personal, single-user tool.
final class UndoHotkeyManager {
    var onUndo: (() -> Void)?

    private var monitor: Any?
    private var letter: UndoHotkeyLetter
    private var modifiers: UndoHotkeyModifiers

    init(
        letter: UndoHotkeyLetter = AppSettings.undoHotkeyLetter,
        modifiers: UndoHotkeyModifiers = AppSettings.undoHotkeyModifiers
    ) {
        self.letter = letter
        self.modifiers = modifiers
    }

    /// Called when the user changes the undo hotkey in Settings, so the change
    /// takes effect immediately without an app restart.
    func update(letter: UndoHotkeyLetter, modifiers: UndoHotkeyModifiers) {
        self.letter = letter
        self.modifiers = modifiers
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
        }
    }

    func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard Int(event.keyCode) == letter.keyCode, !event.isARepeat else { return }

        // Exact-set equality over just {control, option, shift, command}, not
        // .deviceIndependentFlagsMask directly — that mask includes .capsLock,
        // which would silently break this check whenever Caps Lock is on.
        // Command is never in `modifiers.nsEventFlags`, so this also rejects the
        // event whenever Command is held, same as the original hardcoded check.
        let relevantFlags: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        guard event.modifierFlags.intersection(relevantFlags) == modifiers.nsEventFlags else { return }

        onUndo?()
    }
}
