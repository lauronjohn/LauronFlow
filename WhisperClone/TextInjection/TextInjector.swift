import AppKit
import Carbon.HIToolbox

/// Types the dictated transcript into whatever app currently has focus by
/// swapping the pasteboard and synthesizing a Cmd+V, then restoring the
/// user's original pasteboard contents shortly after.
///
/// Must be called on the main thread — `inject(_:)` touches `NSPasteboard`
/// and returns immediately (fire-and-forget); the restore happens
/// asynchronously ~300ms later once the synthetic paste has had time to be
/// processed by the target app, so no thread-safety machinery is needed here.
final class TextInjector {
    private let restoreDelay: TimeInterval = 0.3

    func inject(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let savedItems = Self.captureItems(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        Self.postCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            Self.restore(savedItems, to: pasteboard)
        }
    }

    /// Captures every pasteboard item's full set of (type, data) pairs so the
    /// original clipboard contents can be restored losslessly, rather than
    /// collapsing everything down to a single plain string.
    private static func captureItems(from pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var typeData: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    typeData[type] = data
                }
            }
            return typeData
        }
    }

    private static func restore(_ savedItems: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !savedItems.isEmpty else { return }

        let restoredItems: [NSPasteboardItem] = savedItems.map { typeData in
            let item = NSPasteboardItem()
            for (type, data) in typeData {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode = CGKeyCode(kVK_ANSI_V)

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
