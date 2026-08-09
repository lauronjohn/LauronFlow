import AppKit
import SwiftUI

final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let licenseStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let buyLicenseItem = NSMenuItem(title: "Buy License…", action: #selector(handleBuyLicense), keyEquivalent: "")
    private let statusMessageItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let statsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let historyItem = NSMenuItem(title: "Recent Transcripts", action: nil, keyEquivalent: "")
    private let clearHistoryItem = NSMenuItem(title: "Clear History", action: #selector(handleClearHistory), keyEquivalent: "")
    var onTestTranscription: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onBuyLicense: (() -> Void)?
    var onClearHistory: (() -> Void)?

    private var currentState: AppState = .idle
    private var waveformLevels: [Float] = []
    private var lastWaveformRedraw: Date?
    // Levels arrive far more often (per audio buffer) than an 18px icon needs to
    // redraw; this keeps CPU/redraw cost negligible without any visible lag.
    private let waveformRedrawInterval: TimeInterval = 0.09

    init() {
        statusItem.button?.image = Self.image(for: .idle)
        statusItem.menu = buildMenu()
    }

    func setState(_ state: AppState) {
        currentState = state
        statusItem.button?.image = Self.image(for: state)

        if case .recording = state {
            // Start each recording from a clean, flat waveform rather than whatever
            // levels a previous recording left behind.
            waveformLevels = []
            lastWaveformRedraw = nil
        }

        switch state {
        case .error(let message):
            statusItem.button?.toolTip = message
        case .starting(let message):
            statusItem.button?.toolTip = message
        default:
            statusItem.button?.toolTip = nil
        }

        // Also surfaced as a visible (non-hover) menu row: a tester is unlikely to think to
        // hover the icon, whether what looks broken is an unresponsive first launch or a
        // silent failure to inject text.
        switch state {
        case .starting(let message), .error(let message):
            statusMessageItem.title = message
            statusMessageItem.isHidden = false
        default:
            statusMessageItem.isHidden = true
        }
    }

    /// Feeds a live RMS level into the menu bar icon's mini-waveform. No-ops outside
    /// `.recording` — independent of `AppSettings.showRecordingWidget`, which only
    /// controls the floating widget, not this lower-weight indicator.
    func updateWaveform(level: Float) {
        guard case .recording = currentState else { return }

        let now = Date()
        if let last = lastWaveformRedraw, now.timeIntervalSince(last) < waveformRedrawInterval {
            return
        }
        lastWaveformRedraw = now

        waveformLevels.append(level)
        if waveformLevels.count > WaveformIconRenderer.barCount {
            waveformLevels.removeFirst(waveformLevels.count - WaveformIconRenderer.barCount)
        }
        statusItem.button?.image = WaveformIconRenderer.image(for: waveformLevels)
    }

    /// Refreshes the "N words · N sessions today" menu row. Called once at launch
    /// (so the menu isn't empty before the first dictation) and after every
    /// completed dictation.
    func updateStats() {
        let words = UsageStats.wordsToday
        let sessions = UsageStats.sessionsToday
        statsItem.title = "\(words) word\(words == 1 ? "" : "s") · \(sessions) session\(sessions == 1 ? "" : "s") today"
    }

    /// Rebuilds the "Recent Transcripts" submenu from the current history entries.
    /// `entries` is expected newest-first (already capped) — one hosted SwiftUI row
    /// per entry, plus a "Clear History" action at the bottom when non-empty.
    func updateHistory(entries: [TranscriptHistoryEntry]) {
        let submenu = NSMenu()
        if entries.isEmpty {
            let emptyItem = NSMenuItem(title: "No transcripts yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            for entry in entries {
                let item = NSMenuItem()
                item.view = NSHostingView(rootView: TranscriptHistoryRowView(entry: entry))
                submenu.addItem(item)
            }
            submenu.addItem(.separator())
            // Rebuilt fresh on every call, but `clearHistoryItem` is a single shared
            // instance reused across rebuilds — it must be pulled out of whichever
            // submenu it's still sitting in first, since an NSMenuItem can only belong
            // to one NSMenu at a time and `addItem` throws otherwise.
            clearHistoryItem.menu?.removeItem(clearHistoryItem)
            submenu.addItem(clearHistoryItem)
        }
        historyItem.submenu = submenu
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

        statsItem.isEnabled = false
        menu.addItem(statsItem)

        updateHistory(entries: [])
        menu.addItem(historyItem)
        clearHistoryItem.target = self

        menu.addItem(.separator())

        statusMessageItem.isEnabled = false
        statusMessageItem.isHidden = true
        menu.addItem(statusMessageItem)

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

    @objc private func handleClearHistory() {
        onClearHistory?()
    }
}
