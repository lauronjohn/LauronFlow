import Foundation

enum AppState: Equatable {
    case idle
    case recording
    case transcribing
    case error(String)
}
