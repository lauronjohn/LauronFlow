import Foundation
import os

private let logger = Logger(subsystem: "com.lauronjohn.LauronFlow", category: "vocabulary")

/// Must be read/written on the main thread — `entries` is edited live from the
/// settings UI and read during transcript injection.
final class VocabularyStore: ObservableObject {
    @Published var entries: [VocabularyEntry] = []

    init() {
        guard let data = try? Data(contentsOf: SidecarPaths.vocabularyURL) else { return }
        do {
            entries = try JSONDecoder().decode([VocabularyEntry].self, from: data)
        } catch {
            logger.error("Failed to decode vocabulary.json, starting empty: \(String(describing: error), privacy: .public)")
        }
    }

    func save() {
        try? FileManager.default.createDirectory(
            at: SidecarPaths.supportDirectory,
            withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: SidecarPaths.vocabularyURL)
    }

    /// Applies entries in list order over the accumulating result, so an earlier
    /// entry's output can be re-matched by a later entry (sed-script semantics) —
    /// intentional, not a bug.
    func apply(to text: String) -> String {
        var result = text
        for entry in entries {
            let from = entry.from.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !from.isEmpty else { continue }

            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: from) + "\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }

            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: NSRegularExpression.escapedTemplate(for: entry.to))
        }
        return result
    }
}
