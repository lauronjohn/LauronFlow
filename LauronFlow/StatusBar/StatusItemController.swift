import AppKit

final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var onTestTranscription: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    init() {
        statusItem.button?.image = Self.image(for: .idle)
        statusItem.menu = buildMenu()
    }

    func setState(_ state: AppState) {
        statusItem.button?.image = Self.image(for: state)

        if case .error(let message) = state {
            statusItem.button?.toolTip = message
        } else {
            statusItem.button?.toolTip = nil
        }
    }

    /// Idle/recording use the custom brand glyph (derived from the LauronFlow logo);
    /// transcribing/error stay as system symbols since they're transient/rare states
    /// where a universally recognized icon matters more than brand consistency.
    private static func image(for state: AppState) -> NSImage? {
        switch state {
        case .idle:
            let image = NSImage(named: "MenuGlyph")
            image?.isTemplate = true
            return image
        case .recording:
            // Not a template — keeps its red fill regardless of menu bar appearance,
            // so "recording" reads as an obvious color change, not just a shape change.
            return NSImage(named: "MenuGlyphRecording")
        case .transcribing, .error:
            let symbolName = state == .transcribing ? "waveform" : "exclamationmark.triangle"
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "LauronFlow")
            image?.isTemplate = true
            return image
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let testItem = NSMenuItem(
            title: "Test Transcription",
            action: #selector(handleTestTranscription),
            keyEquivalent: ""
        )
        testItem.target = self
        menu.addItem(testItem)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(handleOpenSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit LauronFlow",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
    }

    @objc private func handleTestTranscription() {
        onTestTranscription?()
    }

    @objc private func handleOpenSettings() {
        onOpenSettings?()
    }
}
