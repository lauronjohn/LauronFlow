import AppKit
import SwiftUI

struct VocabularySettingsView: View {
    @ObservedObject var store: VocabularyStore

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach($store.entries) { $entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            TextField("From", text: $entry.from)
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                            TextField("To", text: $entry.to)
                            Button(role: .destructive) {
                                store.entries.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                        AppScopePicker(bundleID: $entry.appBundleID)
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider()

            HStack {
                Button {
                    store.entries.append(VocabularyEntry(from: "", to: ""))
                } label: {
                    Image(systemName: "plus")
                }
                Spacer()
            }
            .padding(8)
        }
        .onChange(of: store.entries) { _, _ in
            store.save()
        }
        .frame(minWidth: 420, minHeight: 320)
    }
}

/// Per-entry control for scoping a vocabulary replacement to a single app (or
/// leaving it applying everywhere, the default). The currently-selected scope is
/// always kept in the candidate list even if that app isn't running right now, so
/// an already-scoped entry never silently loses its visible selection.
private struct AppScopePicker: View {
    @Binding var bundleID: String?

    var body: some View {
        Picker("Applies to", selection: $bundleID) {
            Text("All Apps").tag(String?.none)
            ForEach(candidates, id: \.bundleID) { candidate in
                Text(candidate.name).tag(String?.some(candidate.bundleID))
            }
        }
        .labelsHidden()
        .font(.caption)
        .frame(maxWidth: 220)
    }

    private var candidates: [(bundleID: String, name: String)] {
        var seen = Set<String>()
        var result: [(bundleID: String, name: String)] = []

        if let bundleID {
            result.append((bundleID, AppDisplayName.resolve(forBundleID: bundleID)))
            seen.insert(bundleID)
        }
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let id = app.bundleIdentifier, !seen.contains(id) else { continue }
            seen.insert(id)
            result.append((id, app.localizedName ?? id))
        }
        return result.sorted { $0.name < $1.name }
    }
}
