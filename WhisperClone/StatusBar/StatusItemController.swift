import AppKit

final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let launchAtLoginItem = NSMenuItem(
        title: "Launch at Login",
        action: nil,
        keyEquivalent: ""
    )
    var onTestTranscription: (() -> Void)?
    var onToggleLaunchAtLogin: (() -> Void)?

    init() {
        statusItem.button?.image = Self.image(for: .idle)
        statusItem.menu = buildMenu()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginItem.state = enabled ? .on : .off
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

        launchAtLoginItem.action = #selector(handleToggleLaunchAtLogin)
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

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

    @objc private func handleToggleLaunchAtLogin() {
        onToggleLaunchAtLogin?()
    }
}
