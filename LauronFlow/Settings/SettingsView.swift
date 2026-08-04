import SwiftUI

private enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case general, vocabulary, shortcuts, license

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .vocabulary: return "Vocabulary"
        case .shortcuts: return "Shortcuts"
        case .license: return "License"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .vocabulary: return "text.book.closed"
        case .shortcuts: return "keyboard"
        case .license: return "key"
        }
    }
}

/// Sidebar layout (matches System Settings' pane-switcher pattern), not `TabView`: on
/// recent macOS SDKs an unstyled `TabView` in a plain window renders as small unlabeled
/// icon buttons crammed into the title bar next to the traffic lights, which is cramped
/// and hard to target. A `NavigationSplitView` sidebar gives every pane a visible label
/// and a full-height click target instead.
struct SettingsView: View {
    @ObservedObject var vocabularyStore: VocabularyStore
    @ObservedObject var licenseManager: LicenseManager
    @State private var selection: SettingsPane? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.systemImage)
                    .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 160, max: 190)
        } detail: {
            let pane = selection ?? .general
            VStack(alignment: .leading, spacing: 0) {
                Text(pane.title)
                    .font(.title2.bold())
                    .padding([.top, .horizontal], 20)
                    .padding(.bottom, 4)

                Group {
                    switch pane {
                    case .general: GeneralSettingsView()
                    case .vocabulary: VocabularySettingsView(store: vocabularyStore)
                    case .shortcuts: ShortcutsSettingsView()
                    case .license: LicenseSettingsView(licenseManager: licenseManager)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 660, idealWidth: 700, minHeight: 460, idealHeight: 500)
    }
}
