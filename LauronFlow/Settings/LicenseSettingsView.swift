import AppKit
import SwiftUI

struct LicenseSettingsView: View {
    @ObservedObject var licenseManager: LicenseManager
    @State private var licenseKeyInput = ""
    @State private var isActivating = false
    @State private var activationError: String?

    var body: some View {
        Form {
            Section {
                statusRow
            } header: {
                Text("Status")
            }

            if case .licensed = licenseManager.state {
                Section {
                    Text("Thanks for buying LauronFlow — it's all yours, no further limits.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    TextField("License Key", text: $licenseKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isActivating)

                    HStack {
                        Button(isActivating ? "Activating…" : "Activate") {
                            activate()
                        }
                        .disabled(isActivating || licenseKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button("Buy License…") {
                            NSWorkspace.shared.open(GumroadConfig.purchaseURL)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if let activationError {
                        Text(activationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Already bought a license?")
                } footer: {
                    Text("Paste the license key from your Gumroad receipt email.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch licenseManager.state {
        case .trial(let daysRemaining):
            LabeledContent("Trial") {
                Text("\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") left")
            }
        case .trialExpired:
            LabeledContent("Trial") {
                Text("Expired").foregroundStyle(.red)
            }
        case .licensed(let email):
            LabeledContent("Licensed") {
                Text(email ?? "Active").foregroundStyle(.green)
            }
        }
    }

    private func activate() {
        isActivating = true
        activationError = nil
        licenseManager.activate(licenseKey: licenseKeyInput) { result in
            DispatchQueue.main.async {
                isActivating = false
                switch result {
                case .success:
                    licenseKeyInput = ""
                case .failure(let error):
                    activationError = error.message
                }
            }
        }
    }
}
