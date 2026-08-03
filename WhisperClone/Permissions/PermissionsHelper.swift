import ApplicationServices
import AVFoundation
import Foundation

enum PermissionsHelper {
    static func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the system Accessibility permission prompt (System Settings deep link) if not
    /// already trusted. Not used until M4's hotkey work, but scoped here per PLAN.md — this
    /// file owns both mic and accessibility permission concerns.
    static func requestAccessibilityAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let options: NSDictionary = [key: true]
        AXIsProcessTrustedWithOptions(options)
    }
}
