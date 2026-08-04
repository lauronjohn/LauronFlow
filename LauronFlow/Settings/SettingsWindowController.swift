import AppKit
import SwiftUI

/// Owns the "Settings" window, lazily creating it once and reusing it across
/// `show()` calls (same lazy-creation shape as `RecordingWidgetController`).
///
/// Driven manually via AppKit, not the SwiftUI `Settings` scene declared in
/// `LauronFlowApp.swift` — that scene is a vestigial placeholder which only
/// exists to stop SwiftUI from spawning a default `WindowGroup` window on
/// launch for this `LSUIElement` (accessory) app, and isn't wired to
/// anything.
final class SettingsWindowController {
    private let store: VocabularyStore
    private var window: NSWindow?

    init(store: VocabularyStore) {
        self.store = store
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        // Rebuilt fresh on every show, not just the first time: GeneralSettingsView
        // snapshots its toggles into @State at init, so reusing a stale hosting
        // view across opens could show outdated values (e.g. if Launch at Login
        // was changed outside the app while this window sat closed).
        window.contentView = NSHostingView(rootView: SettingsView(vocabularyStore: store))
        // Activate first, then order front: this is an LSUIElement (accessory)
        // app, so ordering the window front while LauronFlow still isn't the
        // active app leaves it behind whatever app was frontmost — it looked
        // like the menu item needed a second click, but the real issue was
        // activation happening too late.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 380),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
