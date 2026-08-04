import AppKit
import Carbon.HIToolbox

/// Push-to-talk detector for a configurable physical modifier key (default: Right
/// Option — see `ModifierHotkeyOption`).
///
/// `.flagsChanged` fires on press *and* release of a modifier key and carries
/// no explicit down/up flag, so the down/up transition has to be inferred by
/// comparing the previous and current modifier bit for events whose `keyCode`
/// matches the configured key. Physical key codes name a key *position* (works
/// for standard US keyboard layouts) — this is an accepted limitation, not
/// something this class tries to solve generically.
final class HotkeyManager {
    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: (() -> Void)?

    private var monitor: Any?
    private var isKeyDown = false
    private var option: ModifierHotkeyOption

    init(option: ModifierHotkeyOption = AppSettings.recordHotkeyOption) {
        self.option = option
    }

    /// Called when the user picks a different hotkey in Settings, so the change takes
    /// effect immediately without an app restart. Resets `isKeyDown` since it was
    /// tracking the *previous* key, which may still be physically held.
    func updateOption(_ option: ModifierHotkeyOption) {
        self.option = option
        isKeyDown = false
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }

    func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        isKeyDown = false
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard Int(event.keyCode) == option.keyCode else { return }

        let isNowDown = event.modifierFlags.contains(option.modifierFlag)
        guard isNowDown != isKeyDown else { return }
        isKeyDown = isNowDown

        if isNowDown {
            onHotkeyDown?()
        } else {
            onHotkeyUp?()
        }
    }
}
