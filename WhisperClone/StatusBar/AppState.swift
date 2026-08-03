import Foundation

enum AppState {
    case idle
    case recording
    case transcribing
    case error(String)

    var symbolName: String {
        switch self {
        case .idle: return "waveform"
        case .recording: return "waveform.circle.fill"
        case .transcribing: return "ellipsis.circle"
        case .error: return "exclamationmark.triangle"
        }
    }
}
