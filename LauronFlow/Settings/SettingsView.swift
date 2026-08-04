import SwiftUI

struct SettingsView: View {
    @ObservedObject var vocabularyStore: VocabularyStore

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            VocabularySettingsView(store: vocabularyStore)
                .tabItem { Label("Vocabulary", systemImage: "text.book.closed") }
            ShortcutsSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(minWidth: 460, minHeight: 380)
    }
}
