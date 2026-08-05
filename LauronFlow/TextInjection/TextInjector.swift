import AppKit
import Carbon.HIToolbox

/// Types the dictated transcript into whatever app currently has focus by
/// swapping the pasteboard and synthesizing a Cmd+V, then restoring the
/// user's original pasteboard contents shortly after.
///
/// Must be called on the main thread — `inject(_:)` touches `NSPasteboard`
/// and returns immediately (fire-and-forget); the restore happens
/// asynchronously once the synthetic paste has had time to be processed by
/// the target app, so no thread-safety machinery is needed here.
final class TextInjector {
    /// How long to leave the transcript on the general pasteboard before restoring the
    /// user's previous contents. Must be generous: some apps (Word, Google Docs, heavy
    /// Electron/web apps) read the pasteboard asynchronously and can take well over
    /// 300ms to process a synthetic Cmd+V — a too-early restore is indistinguishable
    /// from "nothing got pasted" from the user's point of view. 1s covers essentially
    /// every real app while keeping the clipboard hijack imperceptible.
    private let restoreDelay: TimeInterval = 1.0
    private var lastInjectedText: String?
    private var pendingRestore: DispatchWorkItem?

    func inject(_ text: String) {
        guard !text.isEmpty else { return }
        lastInjectedText = text

        let pasteboard = NSPasteboard.general
        let savedItems = Self.captureItems(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        Self.postCommandV()

        // Cancel any restore still pending from a previous injection. (Injections are
        // serialized upstream via `isBusy`, so this is defensive, not load-bearing.)
        pendingRestore?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.restoreIfUnclaimed(savedItems, to: pasteboard, injectedText: text)
        }
        pendingRestore = work
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay, execute: work)
    }

    /// Restores the user's original clipboard contents — but only if the pasteboard still
    /// holds the text we injected. If the user copied something else during the restore
    /// window (or a previous restore already ran), their newer content is left alone:
    /// a blind restore here would clobber whatever they just copied, which is worse than
    /// leaving our (already-pasted) transcript on the clipboard.
    private func restoreIfUnclaimed(
        _ savedItems: [[NSPasteboard.PasteboardType: Data]],
        to pasteboard: NSPasteboard,
        injectedText: String
    ) {
        pendingRestore = nil
        guard pasteboard.string(forType: .string) == injectedText else { return }
        Self.restore(savedItems, to: pasteboard)
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
