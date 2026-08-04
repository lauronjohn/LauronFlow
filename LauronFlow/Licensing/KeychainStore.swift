import Foundation
import Security

/// Minimal Keychain-backed key/value store for license state. Keychain is used instead of
/// UserDefaults because it survives app deletion/reinstall, so the trial start date can't be
/// reset just by trashing and re-downloading the app.
struct KeychainStore {
    enum Key: String {
        case firstLaunchDate
        case licenseKey
        case licenseValidated
        case licenseEmail
    }

    let service: String

    func string(for key: Key) -> String? {
        guard let data = read(key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String, for key: Key) {
        write(Data(value.utf8), for: key)
    }

    func bool(for key: Key) -> Bool {
        string(for: key) == "true"
    }

    func set(_ value: Bool, for key: Key) {
        set(value ? "true" : "false", for: key)
    }

    func remove(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func read(_ key: Key) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func write(_ data: Data, for key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }
}
