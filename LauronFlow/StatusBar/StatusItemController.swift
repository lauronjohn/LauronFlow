import AppKit

final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let licenseStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let buyLicenseItem = NSMenuItem(title: "Buy License…", action: #selector(handleBuyLicense), keyEquivalent: "")
    private let startupStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    var onTestTranscription: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onBuyLicense: (() -> Void)?

    init() {
        statusItem.button?.image = Self.image(for: .idle)
        statusItem.menu = buildMenu()
    }

    func setState(_ state: AppState) {
        statusItem.button?.image = Self.image(for: state)

        switch state {
        case .error(let message):
            statusItem.button?.toolTip = message
        case .starting(let message):
            statusItem.button?.toolTip = message
        default:
            statusItem.button?.toolTip = nil
        }

        // Also surfaced as a visible (non-hover) menu row, since a tester is unlikely to
        // think to hover the icon during what looks like an unresponsive first launch.
        if case .starting(let message) = state {
            startupStatusItem.title = message
            startupStatusItem.isHidden = false
        } else {
            startupStatusItem.isHidden = true
        }
    }

    func updateLicenseState(_ state: LicenseState) {
        switch state {
        case .trial(let daysRemaining):
            licenseStatusItem.title = "Trial: \(daysRemaining) day\(daysRemaining == 1 ? "" : "s") left"
            buyLicenseItem.isHidden = false
        case .trialExpired:
            licenseStatusItem.title = "Trial Expired"
            buyLicenseItem.isHidden = false
        case .licensed:
            licenseStatusItem.title = "Licensed"
            buyLicenseItem.isHidden = true
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
        case .transcribing, .starting, .error:
            let symbolName: String
            switch state {
            case .transcribing: symbolName = "waveform"
            case .starting: symbolName = "arrow.down.circle"
            default: symbolName = "exclamationmark.triangle"
            }
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

        startupStatusItem.isEnabled = false
        startupStatusItem.isHidden = true
        menu.addItem(startupStatusItem)

        licenseStatusItem.isEnabled = false
        menu.addItem(licenseStatusItem)
        buyLicenseItem.target = self
        buyLicenseItem.isHidden = true
        menu.addItem(buyLicenseItem)

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

    @objc private func handleBuyLicense() {
        onBuyLicense?()
    }
}
