import Foundation

enum AppState: Equatable {
    case idle
    case recording
    case transcribing
    /// Sidecar process is up but not ready yet — only reachable on a cold model cache
    /// (first launch, or after clearing it), while it's downloading/loading. Associated
    /// text is a human-readable progress line (see `SidecarStatus.displayText`).
    case starting(String)
    case error(String)
}
