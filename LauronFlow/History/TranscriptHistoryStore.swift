import Foundation
import os

private let logger = Logger(subsystem: "com.lauronjohn.LauronFlow", category: "history")
private let historyCap = 20

/// Must be read/written on the main thread — same contract as `VocabularyStore`,
/// which this mirrors: JSON file in Application Support, loaded once at init,
/// explicit `save()` after each mutation.
final class TranscriptHistoryStore: ObservableObject {
    @Published var entries: [TranscriptHistoryEntry] = []

    init() {
        guard let data = try? Data(contentsOf: SidecarPaths.transcriptHistoryURL) else { return }
        do {
            entries = try JSONDecoder().decode([TranscriptHistoryEntry].self, from: data)
        } catch {
            logger.error("Failed to decode history.json, starting empty: \(String(describing: error), privacy: .public)")
        }
    }

    /// Inserts the newest entry first and trims to the last `historyCap` entries.
    func append(text: String, appBundleID: String?) {
        guard !text.isEmpty else { return }
        entries.insert(TranscriptHistoryEntry(text: text, appBundleID: appBundleID), at: 0)
        if entries.count > historyCap {
            entries.removeLast(entries.count - historyCap)
        }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    func save() {
        try? FileManager.default.createDirectory(
            at: SidecarPaths.supportDirectory,
            withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: SidecarPaths.transcriptHistoryURL)
    }
}
