import AppKit
import Foundation
import os

private let logger = Logger(subsystem: "com.lauronjohn.WhisperClone", category: "transcription")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController!
    private let sidecarManager = SidecarProcessManager()
    private let sidecarClient = SidecarClient()
    private let audioRecorder = AudioRecorder()
    private let hotkeyManager = HotkeyManager()
    private var accessibilityObserverTimer: Timer?
    private var isBusy = false
    private var currentRecordingURL: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController()
        statusItemController.onTestTranscription = { [weak self] in
            self?.runTestTranscription()
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

        PermissionsHelper.requestMicrophoneAccess { granted in
            if !granted {
                logger.error("Microphone access not granted; recording will fail until enabled in System Settings.")
            }
        }

        PermissionsHelper.requestAccessibilityAccess()
        accessibilityObserverTimer = PermissionsHelper.observeAccessibilityTrust { [weak self] trusted in
            self?.handleAccessibilityTrustChange(trusted)
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
            return true
        } catch {
            logger.error("Failed to start recording: \(String(describing: error), privacy: .public)")
            statusItemController.setState(.error("\(error)"))
            isBusy = false
            currentRecordingURL = nil
            return false
        }
    }

    private func finishRecordingAndTranscribe() {
        guard isBusy, let wavURL = currentRecordingURL else { return }
        currentRecordingURL = nil
        audioRecorder.stop()
        statusItemController.setState(.transcribing)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            defer { try? FileManager.default.removeItem(at: wavURL) }
            do {
                let text = try self.sidecarClient.transcribe(wavPath: wavURL)
                logger.notice("Transcript: \(text, privacy: .public)")
                DispatchQueue.main.async {
                    self.statusItemController.setState(.idle)
                    self.isBusy = false
                }
            } catch {
                logger.error("Transcription failed: \(String(describing: error), privacy: .public)")
                DispatchQueue.main.async {
                    self.statusItemController.setState(.error("\(error)"))
                    self.isBusy = false
                }
            }
        }
    }
}
