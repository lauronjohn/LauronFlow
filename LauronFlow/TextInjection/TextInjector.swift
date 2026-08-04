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
    private var lastInjectedText: String?

    func inject(_ text: String) {
        guard !text.isEmpty else { return }
        lastInjectedText = text

        let pasteboard = NSPasteboard.general
        let savedItems = Self.captureItems(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        Self.postCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            Self.restore(savedItems, to: pasteboard)
        }
    }

    /// Removes the last text this instance injected by sending one backspace
    /// per `Character` (extended grapheme cluster) it contains — matching how
    /// most Cocoa text fields delete one visual character per backspace.
    /// One-shot: calling this again before the next `inject(_:)` is a no-op.
    ///
    /// Two accepted limitations, inherent to a backspace-based undo with no
    /// access to the target app's text buffer: some Chromium/Electron apps
    /// delete by UTF-16 code unit rather than grapheme cluster, so complex
    /// emoji/ZWJ sequences may need more than one backspace there; and this
    /// assumes focus/cursor hasn't moved since injection — if the user
    /// clicked elsewhere first, the backspaces land in the wrong place.
    func undo() {
        guard let text = lastInjectedText, !text.isEmpty else { return }
        lastInjectedText = nil
        Self.postBackspaces(count: text.count)
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

    private static func postBackspaces(count: Int) {
        let source = CGEventSource(stateID: .hidSystemState)
        let deleteKeyCode = CGKeyCode(kVK_Delete)

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: deleteKeyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: deleteKeyCode, keyDown: false)
        else { return }

        for _ in 0..<count {
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
