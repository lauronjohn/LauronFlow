import SwiftUI

struct VocabularySettingsView: View {
    @ObservedObject var store: VocabularyStore

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach($store.entries) { $entry in
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
