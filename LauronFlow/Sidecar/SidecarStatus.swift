import Foundation

/// Mirrors the JSON the sidecar writes to `SidecarPaths.statusURL` while downloading or
/// loading the model on a cold cache (see `model.py`'s `_write_status`). Only present
/// during that window — absent entirely on every launch after the first.
struct SidecarStatus: Decodable {
    let phase: String
    let downloadedBytes: Int64?
    let totalBytes: Int64?

    enum CodingKeys: String, CodingKey {
        case phase
        case downloadedBytes = "downloaded_bytes"
        case totalBytes = "total_bytes"
    }

    /// Reads and decodes the status file directly — no caching, since callers already
    /// poll on a timer and the file is small and rewritten atomically on the Python
    /// side (temp file + rename), so a torn read isn't a concern.
    static func read() -> SidecarStatus? {
        guard let data = try? Data(contentsOf: SidecarPaths.statusURL) else { return nil }
        return try? JSONDecoder().decode(SidecarStatus.self, from: data)
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    /// Human-readable one-liner for the menu bar, e.g. "Downloading model… 1.2 GB of
    /// 2.3 GB (52%)" or, if the total lookup failed, "Downloading model… 1.2 GB".
    var displayText: String {
        switch phase {
        case "downloading":
            let downloaded = Self.byteFormatter.string(fromByteCount: downloadedBytes ?? 0)
            guard let totalBytes, totalBytes > 0 else {
                return "Downloading model… \(downloaded)"
            }
            let total = Self.byteFormatter.string(fromByteCount: totalBytes)
            let percent = Int((Double(downloadedBytes ?? 0) / Double(totalBytes) * 100).rounded())
            return "Downloading model… \(downloaded) of \(total) (\(percent)%)"
        case "loading":
            return "Loading model into memory…"
        default:
            return "Starting up…"
        }
    }
}
