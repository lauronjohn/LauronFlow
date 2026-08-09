import Foundation

/// Lightweight "words dictated / sessions" counters for today, shown as a menu bar
/// row. Backed by plain UserDefaults (no JSON store needed for two integers) with a
/// stored date checked lazily on each read/write — this re-derives on demand rather
/// than needing a background midnight timer, the same posture `LicenseManager` takes
/// for its own date-based state.
enum UsageStats {
    private static let wordsKey = "usageStatsWordsToday"
    private static let sessionsKey = "usageStatsSessionsToday"
    private static let lastResetDateKey = "usageStatsLastResetDate"

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    static var wordsToday: Int {
        rolloverIfNeeded()
        return UserDefaults.standard.integer(forKey: wordsKey)
    }

    static var sessionsToday: Int {
        rolloverIfNeeded()
        return UserDefaults.standard.integer(forKey: sessionsKey)
    }

    /// Records one completed dictation. Counts as soon as a non-empty transcript
    /// comes back from the sidecar+vocabulary pipeline — "words dictated" reflects
    /// what was said, not whether it successfully landed in a text field afterward.
    static func recordSession(wordCount: Int) {
        rolloverIfNeeded()
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: wordsKey) + wordCount, forKey: wordsKey)
        defaults.set(defaults.integer(forKey: sessionsKey) + 1, forKey: sessionsKey)
    }

    private static func rolloverIfNeeded() {
        let today = dateFormatter.string(from: Date())
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: lastResetDateKey) != today else { return }
        defaults.set(0, forKey: wordsKey)
        defaults.set(0, forKey: sessionsKey)
        defaults.set(today, forKey: lastResetDateKey)
    }
}
