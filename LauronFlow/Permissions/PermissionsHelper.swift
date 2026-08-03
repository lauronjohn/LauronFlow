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

    /// Polls `isAccessibilityTrusted` since macOS gives no callback for grant/revoke while the
    /// app is running. Fires `onChange` immediately with the current value, then again only when
    /// the value flips (edge-triggered), so the caller can start/stop the hotkey monitor in
    /// response to the user granting or revoking Accessibility access in System Settings.
    @discardableResult
    static func observeAccessibilityTrust(interval: TimeInterval = 2.0, onChange: @escaping (Bool) -> Void) -> Timer {
        var lastValue = isAccessibilityTrusted
        onChange(lastValue)

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            let currentValue = isAccessibilityTrusted
            guard currentValue != lastValue else { return }
            lastValue = currentValue
            onChange(currentValue)
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
