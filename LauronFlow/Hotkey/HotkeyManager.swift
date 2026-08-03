import AppKit
import Carbon.HIToolbox

/// Push-to-talk detector for the physical Right Option key.
///
/// `.flagsChanged` fires on press *and* release of a modifier key and carries
/// no explicit down/up flag, so the down/up transition has to be inferred by
/// comparing the previous and current `.option` bit for events whose
/// `keyCode` is the Right Option key. `kVK_RightOption` names a physical key
/// position (works for standard US keyboard layouts) — this is an accepted
/// limitation, not something this class tries to solve generically.
final class HotkeyManager {
    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: (() -> Void)?

    private var monitor: Any?
    private var isKeyDown = false

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
        guard Int(event.keyCode) == kVK_RightOption else { return }

        let isNowDown = event.modifierFlags.contains(.option)
        guard isNowDown != isKeyDown else { return }
        isKeyDown = isNowDown

        if isNowDown {
            onHotkeyDown?()
        } else {
            onHotkeyUp?()
        }
    }
}
