import AppKit

final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var onTestTranscription: (() -> Void)?

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

    private static func image(for state: AppState) -> NSImage? {
        let symbolName: String
        switch state {
        case .idle: symbolName = "mic"
        case .recording: symbolName = "mic.fill"
        case .transcribing: symbolName = "waveform"
        case .error: symbolName = "exclamationmark.triangle"
        }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "WhisperClone")
        image?.isTemplate = true
        return image
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
