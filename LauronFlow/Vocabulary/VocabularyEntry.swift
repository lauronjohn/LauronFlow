import Foundation

struct VocabularyEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var from: String
    var to: String
    /// Bundle identifier of the one app this entry applies to, or `nil` to apply
    /// everywhere (the default, and the only behavior before this field existed —
    /// declared `Optional` so older `vocabulary.json` files without this key decode
    /// straight to `nil` via `Codable` synthesis, no migration needed).
    var appBundleID: String?

    init(id: UUID = UUID(), from: String, to: String, appBundleID: String? = nil) {
        self.id = id
        self.from = from
        self.to = to
        self.appBundleID = appBundleID
    }
}
