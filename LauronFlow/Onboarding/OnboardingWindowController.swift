import AppKit
import SwiftUI

/// Shows the one-time first-run window and blocks until "Get Started" is clicked,
/// the same "launch pauses until acknowledged" contract the old trial-start
/// `NSAlert.runModal()` had before this replaced it — just with room for more than
/// an alert can hold. No close button in the style mask, so the button really is
/// the only way out.
final class OnboardingWindowController {
    private var window: NSWindow?

    func showBlocking() {
        let window = makeWindow()
        self.window = window
        NSApp.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: window)
        window.orderOut(nil)
        self.window = nil
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to LauronFlow"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: OnboardingView { [weak self] in
            self?.finish()
        })
        return window
    }

    private func finish() {
        AppSettings.hasCompletedOnboarding = true
        NSApp.stopModal()
    }
}
