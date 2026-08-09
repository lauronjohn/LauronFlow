import AppKit
import SwiftUI

/// One row in the menu bar's "Recent Transcripts" submenu: truncated text, a light
/// timestamp/app subtitle, and a copy button — hosted via `NSHostingView` inside an
/// `NSMenuItem`, since a menu that's only open momentarily doesn't need live
/// SwiftUI reactivity, just a one-shot render per open.
struct TranscriptHistoryRowView: View {
    let entry: TranscriptHistoryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.text)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .truncationMode(.tail)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(entry.text, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(width: 280, alignment: .leading)
    }

    private var subtitle: String {
        let time = entry.date.formatted(date: .omitted, time: .shortened)
        guard let appBundleID = entry.appBundleID else { return time }
        return "\(time) · \(AppDisplayName.resolve(forBundleID: appBundleID))"
    }
}
