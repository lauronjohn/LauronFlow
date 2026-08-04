import Foundation

struct VocabularyEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var from: String
    var to: String

    init(id: UUID = UUID(), from: String, to: String) {
        self.id = id
        self.from = from
        self.to = to
    }
}
