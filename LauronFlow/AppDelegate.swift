import AppKit
import Carbon.HIToolbox
import Foundation
import os

private let logger = Logger(subsystem: "com.lauronjohn.LauronFlow", category: "transcription")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController!
    private let sidecarManager = SidecarProcessManager()
    private let sidecarClient = SidecarClient()
    private let audioRecorder = AudioRecorder()
    private let hotkeyManager = HotkeyManager()
    private let textInjector = TextInjector()
    private let recordingWidget = RecordingWidgetController()
    private var accessibilityObserverTimer: Timer?
    private var isBusy = false
    private var currentRecordingURL: URL?
    private var currentRecordingStartedAt: Date?

    /// Recordings shorter than this are treated as an accidental hotkey tap, not a real
    /// utterance, and are dropped without ever reaching the sidecar.
    private let minimumRecordingDuration: TimeInterval = 0.3

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController()
        statusItemController.onTestTranscription = { [weak self] in
            self?.runTestTranscription()
        }
        statusItemController.setLaunchAtLoginEnabled(LaunchAtLoginManager.isEnabled)
        statusItemController.onToggleLaunchAtLogin = { [weak self] in
            LaunchAtLoginManager.setEnabled(!LaunchAtLoginManager.isEnabled)
            self?.statusItemController.setLaunchAtLoginEnabled(LaunchAtLoginManager.isEnabled)
        }

        sidecarManager.onCrash = { [weak self] message in
            DispatchQueue.main.async {
                self?.statusItemController.setState(.error(message))
            }
        }
        sidecarManager.start()

        hotkeyManager.onHotkeyDown = { [weak self] in
            DispatchQueue.main.async {
                _ = self?.beginRecording()
            }
        }
        hotkeyManager.onHotkeyUp = { [weak self] in
            DispatchQueue.main.async {
                self?.finishRecordingAndTranscribe()
            }
        }

        PermissionsHelper.requestMicrophoneAccess { [weak self] granted in
            if !granted {
                logger.error("Microphone access not granted; recording will fail until enabled in System Settings.")
                self?.statusItemController.setState(.error(
                    "Microphone access denied — grant it in System Settings > Privacy & Security > Microphone."
                ))
            }
        }

        PermissionsHelper.requestAccessibilityAccess()
        accessibilityObserverTimer = PermissionsHelper.observeAccessibilityTrust { [weak self] trusted in
            self?.handleAccessibilityTrustChange(trusted)
        }

        audioRecorder.onLevelUpdate = { [weak self] level in
            self?.recordingWidget.updateLevel(level)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityObserverTimer?.invalidate()
        hotkeyManager.stop()
        sidecarManager.stop()
    }

    private func handleAccessibilityTrustChange(_ trusted: Bool) {
        if trusted {
            hotkeyManager.start()
            if !isBusy {
                statusItemController.setState(.idle)
            }
        } else {
            hotkeyManager.stop()
            if !isBusy {
                statusItemController.setState(.error(
                    "Accessibility permission required for the push-to-talk hotkey — grant it in System Settings > Privacy & Security > Accessibility."
                ))
            }
        }
    }

    private func runTestTranscription() {
        guard beginRecording() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.finishRecordingAndTranscribe()
        }
    }

    /// Starts a recording. Returns whether it actually started (false if already busy, the
    /// sidecar isn't ready, or the audio engine failed to start) so callers can decide whether
    /// to expect a matching finish. Shared by both the manual "Test Transcription" menu item
    /// (fixed 3s duration) and the push-to-talk hotkey (duration = how long the key is held).
    @discardableResult
    private func beginRecording() -> Bool {
        guard !isBusy else { return false }
        guard FileManager.default.fileExists(atPath: SidecarPaths.socketURL.path) else {
            statusItemController.setState(.error("Sidecar still starting up — try again in a few seconds."))
            return false
        }

        isBusy = true
        statusItemController.setState(.recording)

        do {
            currentRecordingURL = try audioRecorder.start()
            currentRecordingStartedAt = Date()
            recordingWidget.show()
            return true
        } catch {
            logger.error("Failed to start recording: \(String(describing: error), privacy: .public)")
            statusItemController.setState(.error("\(error)"))
            isBusy = false
            currentRecordingURL = nil
            return false
        }
    }

    /// Types `text` into whatever has focus. Must be called on the main thread.
    /// Injection depends on Accessibility trust (same permission the hotkey needs) — without it
    /// a synthetic Cmd+V is silently ignored by the system, which would otherwise look like a
    /// dead end with no explanation, so that's checked explicitly here. Also skips while macOS's
    /// system-wide secure input mode is active (e.g. a password field has focus) since synthetic
    /// keyboard events are blocked from reaching secure fields by design.
    private func injectTranscript(_ text: String) {
        defer { recordingWidget.hide() }

        guard PermissionsHelper.isAccessibilityTrusted else {
            statusItemController.setState(.error(
                "Transcribed but couldn't type it — Accessibility permission required. Grant it in System Settings > Privacy & Security > Accessibility."
            ))
            return
        }
        guard !IsSecureEventInputEnabled() else {
            statusItemController.setState(.error("Transcribed but couldn't type it — a secure input field (e.g. a password field) has focus."))
            return
        }

        textInjector.inject(text)
        statusItemController.setState(.idle)
    }

    private func finishRecordingAndTranscribe() {
        guard isBusy, let wavURL = currentRecordingURL else { return }
        currentRecordingURL = nil
        audioRecorder.stop()

        let duration = currentRecordingStartedAt.map { Date().timeIntervalSince($0) } ?? minimumRecordingDuration
        currentRecordingStartedAt = nil

        guard duration >= minimumRecordingDuration else {
            // Too short to be a real utterance — almost certainly an accidental hotkey tap.
            // Drop it without ever reaching the sidecar.
            try? FileManager.default.removeItem(at: wavURL)
            statusItemController.setState(.idle)
            recordingWidget.hide()
            isBusy = false
            return
        }

        statusItemController.setState(.transcribing)
        recordingWidget.setTranscribing()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            defer { try? FileManager.default.removeItem(at: wavURL) }
            do {
                let text = try self.sidecarClient.transcribe(wavPath: wavURL)
                logger.notice("Transcript: \(text, privacy: .public)")
                DispatchQueue.main.async {
                    self.injectTranscript(text)
                    self.isBusy = false
                }
            } catch {
                logger.error("Transcription failed: \(String(describing: error), privacy: .public)")
                DispatchQueue.main.async {
                    self.statusItemController.setState(.error("\(error)"))
                    self.recordingWidget.hide()
                    self.isBusy = false
                }
            }
        }
    }
}
