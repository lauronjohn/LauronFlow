import Foundation

struct TranscriptHistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let date: Date
    /// The app that was frontmost when this dictation started, if known — shown as
    /// light context in the history list (e.g. "dictated in Xcode").
    let appBundleID: String?

    init(id: UUID = UUID(), text: String, date: Date = Date(), appBundleID: String?) {
        self.id = id
        self.text = text
        self.date = date
        self.appBundleID = appBundleID
    }
}
