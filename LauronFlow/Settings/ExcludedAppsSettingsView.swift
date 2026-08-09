import AppKit
import SwiftUI

/// Lets the user pick apps where the floating recording widget should never appear,
/// even when it's otherwise enabled in General. Add-candidates come from currently
/// running apps; already-excluded apps are resolved back to a display name via
/// `NSWorkspace` so the list stays readable even after that app has quit.
struct ExcludedAppsSettingsView: View {
    @State private var excludedApps: [String] = AppSettings.excludedApps
    @State private var selectedCandidate: String?

    var body: some View {
        VStack(spacing: 0) {
            if excludedApps.isEmpty {
                VStack(spacing: 6) {
                    Text("No apps excluded")
                        .foregroundStyle(.secondary)
                    Text("The floating widget shows everywhere while recording.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(excludedApps, id: \.self) { bundleID in
                        HStack {
                            Text(displayName(for: bundleID))
                            Spacer()
                            Text(bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button(role: .destructive) {
                                excludedApps.removeAll { $0 == bundleID }
                                AppSettings.excludedApps = excludedApps
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Picker("Add app", selection: $selectedCandidate) {
                    Text("Choose a running app…").tag(String?.none)
                    ForEach(runningCandidates, id: \.bundleID) { candidate in
                        Text(candidate.name).tag(String?.some(candidate.bundleID))
                    }
                }
                .labelsHidden()

                Button("Add") {
                    guard let bundleID = selectedCandidate else { return }
                    excludedApps.append(bundleID)
                    AppSettings.excludedApps = excludedApps
                    selectedCandidate = nil
                }
                .disabled(selectedCandidate == nil)

                Spacer()
            }
            .padding(8)
        }
        .frame(minWidth: 420, minHeight: 320)
    }

    private var runningCandidates: [(bundleID: String, name: String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (bundleID: String, name: String)? in
                guard let bundleID = app.bundleIdentifier, !excludedApps.contains(bundleID) else { return nil }
                return (bundleID, app.localizedName ?? bundleID)
            }
            .sorted { $0.name < $1.name }
    }

    private func displayName(for bundleID: String) -> String {
        AppDisplayName.resolve(forBundleID: bundleID)
    }
}
