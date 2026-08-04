import SwiftUI

/// Uses local `@State`, synced from the source of truth once at init and
/// pushed back out via `.onChange`, rather than a plain `Binding(get:set:)`
/// directly over `LaunchAtLoginManager`/`AppSettings` — a `Toggle` driven by
/// a Binding with no `@State`/`@Published` behind it has nothing to trigger
/// a re-render after tapping, so the switch doesn't visually flip even
/// though the underlying value did change. `SettingsWindowController`
/// recreates this view fresh each time the window is shown, so the initial
/// snapshot here can't go stale across opens.
struct GeneralSettingsView: View {
    @State private var launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
    @State private var showRecordingWidget = AppSettings.showRecordingWidget
    @State private var vocabularyEnabled = AppSettings.vocabularyEnabled

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
                .onChange(of: launchAtLoginEnabled) { _, newValue in
                    LaunchAtLoginManager.setEnabled(newValue)
                }
            Toggle("Show floating recording widget", isOn: $showRecordingWidget)
                .onChange(of: showRecordingWidget) { _, newValue in
                    AppSettings.showRecordingWidget = newValue
                }
            Toggle("Enable vocabulary replacements", isOn: $vocabularyEnabled)
                .onChange(of: vocabularyEnabled) { _, newValue in
                    AppSettings.vocabularyEnabled = newValue
                }
        }
        .padding()
    }
}
