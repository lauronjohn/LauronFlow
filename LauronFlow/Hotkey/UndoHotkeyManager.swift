import AppKit
import Carbon.HIToolbox

/// Global hotkey for "undo last dictation": Control+Option+Z.
///
/// Cmd+Z and Option+Delete were both ruled out — a global `NSEvent` monitor
/// can only observe events, never consume them, so binding to a shortcut a
/// target app (or macOS itself) already handles natively would cause a
/// double-delete. Control+Option+Z isn't a default Cocoa or system binding;
/// the one accepted caveat (same spirit as `HotkeyManager`'s `kVK_RightOption`
/// note) is that Control+Option is macOS's VoiceOver modifier pair, so this
/// could collide with a VoiceOver command if VoiceOver is enabled — acceptable
/// for a personal, single-user tool.
final class UndoHotkeyManager {
    var onUndo: (() -> Void)?

    private var monitor: Any?

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
        guard Int(event.keyCode) == kVK_ANSI_Z, !event.isARepeat else { return }

        // Containment, not exact-set equality against .deviceIndependentFlagsMask —
        // that mask includes .capsLock, which would silently break this check
        // whenever Caps Lock is on. HotkeyManager avoids the same class of bug.
        let flags = event.modifierFlags
        guard
            flags.contains(.control), flags.contains(.option),
            !flags.contains(.command), !flags.contains(.shift)
        else { return }

        onUndo?()
    }
}
