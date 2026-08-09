import AppKit

/// Resolves a bundle identifier to a human-readable app name, even if that app
/// isn't currently running — used anywhere a bundle ID is stored (excluded apps,
/// per-app vocabulary scope) and needs to be shown back to the user.
enum AppDisplayName {
    static func resolve(forBundleID bundleID: String) -> String {
        guard
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
            let bundle = Bundle(url: url),
            let name = (bundle.infoDictionary?["CFBundleName"] as? String) ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
        else { return bundleID }
        return name
    }
}
