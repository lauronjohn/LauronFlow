import AppKit

final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusBar.squareLength)
    var onTestTranscription: (() -> Void)?

    init() {
        statusItem.button?.image = NSImage(
            systemSymbolName: AppState.idle.symbolName,
            accessibilityDescription: "WhisperClone"
        )
        statusItem.menu = buildMenu()
    }

    func setState(_ state: AppState) {
        statusItem.button?.image = NSImage(
            systemSymbolName: state.symbolName,
            accessibilityDescription: "WhisperClone"
        )
        if case .error(let message) = state {
            statusItem.button?.toolTip = message
        } else {
            statusItem.button?.toolTip = nil
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

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit WhisperClone",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
    }

    @objc private func handleTestTranscription() {
        onTestTranscription?()
    }
}
