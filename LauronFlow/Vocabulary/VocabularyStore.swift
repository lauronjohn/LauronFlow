import Foundation
import os

private let logger = Logger(subsystem: "com.lauronjohn.LauronFlow", category: "vocabulary")

/// Must be read/written on the main thread — `entries` is edited live from the
/// settings UI and read during transcript injection.
final class VocabularyStore: ObservableObject {
    @Published var entries: [VocabularyEntry] = []

    /// Compiled-regex cache keyed by entry identity. `apply(to:for:)` previously
    /// compiled every pattern on every dictation; compiling is the expensive part of
    /// `NSRegularExpression` and patterns change only when the user edits settings.
    /// Stale entries for deleted vocabulary lines are evicted in `save()`.
    private struct CachedRegex {
        let pattern: String
        let regex: NSRegularExpression
    }
    private var compiledRegexCache: [UUID: CachedRegex] = [:]

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
        evictStaleRegexCache()
    }

    /// Applies entries in list order over the accumulating result, so an earlier
    /// entry's output can be re-matched by a later entry (sed-script semantics) —
    /// intentional, not a bug. `bundleID` is the frontmost app's bundle identifier
    /// when recording started (nil if unknown); entries scoped to a *different* app
    /// are skipped in place, preserving that ordering for the entries that do apply.
    func apply(to text: String, for bundleID: String? = nil) -> String {
        var result = text
        for entry in entries {
            if let entryScope = entry.appBundleID, entryScope != bundleID { continue }

            let from = entry.from.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !from.isEmpty else { continue }

            guard let regex = compiledRegex(for: entry, from: from) else { continue }

            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: NSRegularExpression.escapedTemplate(for: entry.to))
        }
        return result
    }

    /// Returns the compiled regex for an entry, compiling and caching it on first use.
    /// The cache is validated against the entry's current `from` pattern, so an entry
    /// edited in-place (same `id`, new pattern) recompiles instead of reusing a stale one.
    private func compiledRegex(for entry: VocabularyEntry, from: String) -> NSRegularExpression? {
        if let cached = compiledRegexCache[entry.id], cached.pattern == from {
            return cached.regex
        }

        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: from) + "\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        compiledRegexCache[entry.id] = CachedRegex(pattern: from, regex: regex)
        return regex
    }

    private func evictStaleRegexCache() {
        let liveIDs = Set(entries.map(\.id))
        for key in compiledRegexCache.keys where !liveIDs.contains(key) {
            compiledRegexCache.removeValue(forKey: key)
        }
    }
}
