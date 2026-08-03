import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController!
    private let sidecarManager = SidecarProcessManager()
    private let sidecarClient = SidecarClient()
    private let audioRecorder = AudioRecorder()
    private var isBusy = false

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

        PermissionsHelper.requestMicrophoneAccess { granted in
            if !granted {
                NSLog("Microphone access not granted; recording will fail until enabled in System Settings.")
            }
        }
        PermissionsHelper.requestAccessibilityAccess()
    }

    func applicationWillTerminate(_ notification: Notification) {
        sidecarManager.stop()
    }

    private func runTestTranscription() {
        guard !isBusy else { return }
        guard FileManager.default.fileExists(atPath: SidecarPaths.socketURL.path) else {
            statusItemController.setState(.error("Sidecar still starting up — try again in a few seconds."))
            return
        }

        isBusy = true
        statusItemController.setState(.recording)

        let wavURL: URL
        do {
            wavURL = try audioRecorder.start()
        } catch {
            NSLog("Failed to start recording: \(error)")
            statusItemController.setState(.error("\(error)"))
            isBusy = false
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.finishTestTranscription(wavURL: wavURL)
        }
    }

    private func finishTestTranscription(wavURL: URL) {
        audioRecorder.stop()
        statusItemController.setState(.transcribing)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            defer { try? FileManager.default.removeItem(at: wavURL) }
            do {
                let text = try self.sidecarClient.transcribe(wavPath: wavURL)
                NSLog("Transcript: \(text)")
                DispatchQueue.main.async {
                    self.statusItemController.setState(.idle)
                    self.isBusy = false
                }
            } catch {
                NSLog("Transcription failed: \(error)")
                DispatchQueue.main.async {
                    self.statusItemController.setState(.error("\(error)"))
                    self.isBusy = false
                }
            }
        }
    }
}
