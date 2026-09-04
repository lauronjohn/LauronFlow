import Foundation

enum LicenseState: Equatable {
    case trial(daysRemaining: Int)
    case trialExpired
    case licensed(email: String?)

    var isUsable: Bool {
        switch self {
        case .trial, .licensed: return true
        case .trialExpired: return false
        }
    }
}

enum LicenseError: Error {
    case invalidKey(String)
    case network(String)
    case revoked(String)

    var message: String {
        switch self {
        case .invalidKey(let message), .network(let message), .revoked(let message):
            return message
        }
    }
}

/// Trial-then-buy gate: 14 days from first launch, tracked in Keychain (see KeychainStore)
/// so trashing and re-downloading the app doesn't reset the clock. A valid Gumroad license
/// key skips the trial entirely. This is the only network call LauronFlow makes — audio and
/// transcripts never leave the device; only the license key does, to Gumroad's verify API.
final class LicenseManager: ObservableObject {
    static let trialDuration: TimeInterval = 14 * 24 * 60 * 60

    @Published private(set) var state: LicenseState
    /// True only for the launch that just started the trial clock, so the app can show a
    /// one-time "your trial has started" notice instead of on every subsequent launch.
    let isFirstLaunch: Bool

    private let keychain = KeychainStore(service: "com.lauronjohn.LauronFlow.license")

    init() {
        // The trial start date is recorded in three places (Keychain, UserDefaults, and
        // a file in Application Support) and the *earliest* known value wins. Clearing
        // any one of them — e.g. a user only wiping the Keychain item — can't restart
        // the trial, because the older value still survives somewhere and gets written
        // back. Same posture the license keys take: survive app deletion/reinstall.
        if let earliest = Self.earliestRecordedFirstLaunch(keychain: keychain) {
            isFirstLaunch = false
            Self.persistFirstLaunch(earliest, keychain: keychain)
        } else {
            isFirstLaunch = true
            Self.persistFirstLaunch(Date(), keychain: keychain)
        }
        state = Self.computeState(keychain: keychain)

        if case .licensed = state {
            revalidateCachedLicense()
        }
    }

    /// Re-derives trial-vs-expired from the clock. Cheap, so callers (e.g. the hotkey handler)
    /// can call this right before gating an action instead of relying on a background timer to
    /// have already flipped `state` across the trial boundary.
    @discardableResult
    func refreshState() -> LicenseState {
        let newState = Self.computeState(keychain: keychain)
        if newState != state {
            state = newState
        }
        return state
    }

    func activate(licenseKey: String, completion: @escaping (Result<Void, LicenseError>) -> Void) {
        let trimmed = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        verify(licenseKey: trimmed, incrementUses: true) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                if response.purchase?.refunded == true || response.purchase?.chargebacked == true {
                    completion(.failure(.revoked("This license was refunded or charged back.")))
                    return
                }
                self.keychain.set(trimmed, for: .licenseKey)
                self.keychain.set(true, for: .licenseValidated)
                if let email = response.purchase?.email {
                    self.keychain.set(email, for: .licenseEmail)
                }
                DispatchQueue.main.async {
                    self.state = .licensed(email: response.purchase?.email)
                }
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Silent background check on launch to catch refunds/chargebacks on a previously-activated
    /// license. Network failures (e.g. offline) intentionally leave the cached license alone —
    /// dictation is a local-first feature and must survive being offline. An explicit response
    /// from Gumroad that the key is invalid/revoked does revoke, since that's a definitive
    /// server verdict, not a connectivity blip.
    private func revalidateCachedLicense() {
        guard let key = keychain.string(for: .licenseKey) else { return }
        verify(licenseKey: key, incrementUses: false) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                guard response.purchase?.refunded == true || response.purchase?.chargebacked == true else { return }
                self.revokeCachedLicense()
            case .failure(let error):
                if case .network = error { return }
                self.revokeCachedLicense()
            }
        }
    }

    private func revokeCachedLicense() {
        keychain.remove(.licenseKey)
        keychain.remove(.licenseValidated)
        keychain.remove(.licenseEmail)
        DispatchQueue.main.async {
            self.state = Self.computeState(keychain: self.keychain)
        }
    }

    private func verify(
        licenseKey: String,
        incrementUses: Bool,
        completion: @escaping (Result<GumroadVerifyResponse, LicenseError>) -> Void
    ) {
        guard !licenseKey.isEmpty else {
            completion(.failure(.invalidKey("Enter a license key.")))
            return
        }

        var request = URLRequest(url: GumroadConfig.verifyURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "product_id", value: GumroadConfig.productID),
            URLQueryItem(name: "license_key", value: licenseKey),
            URLQueryItem(name: "increment_uses_count", value: incrementUses ? "true" : "false")
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                completion(.failure(.network(error.localizedDescription)))
                return
            }
            guard let data, let decoded = try? JSONDecoder().decode(GumroadVerifyResponse.self, from: data) else {
                completion(.failure(.network("Unexpected response from the license server.")))
                return
            }
            guard decoded.success else {
                completion(.failure(.invalidKey(decoded.message ?? "Invalid license key.")))
                return
            }
            completion(.success(decoded))
        }.resume()
    }

    private static func computeState(keychain: KeychainStore) -> LicenseState {
        if keychain.string(for: .licenseKey) != nil, keychain.bool(for: .licenseValidated) {
            return .licensed(email: keychain.string(for: .licenseEmail))
        }

        guard let startString = keychain.string(for: .firstLaunchDate),
              let start = ISO8601DateFormatter().date(from: startString)
        else {
            return .trial(daysRemaining: Int(trialDuration / 86400))
        }

        let remaining = trialDuration - Date().timeIntervalSince(start)
        guard remaining > 0 else { return .trialExpired }
        return .trial(daysRemaining: Int(ceil(remaining / 86400)))
    }

    // MARK: - Trial start persistence (redundant stores, earliest wins)

    /// UserDefaults key for the duplicated trial-start record.
    private static let trialStartDefaultsKey = "trialStartDateISO"

    private static var trialStartFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LauronFlow/trial_start.txt")
    }

    /// Reads every record of the trial start date and returns the earliest valid one.
    private static func earliestRecordedFirstLaunch(keychain: KeychainStore) -> Date? {
        let formatter = ISO8601DateFormatter()
        var candidates: [Date] = []

        if let s = keychain.string(for: .firstLaunchDate), let d = formatter.date(from: s) {
            candidates.append(d)
        }
        if let s = UserDefaults.standard.string(forKey: trialStartDefaultsKey),
           let d = formatter.date(from: s) {
            candidates.append(d)
        }
        if let s = try? String(contentsOf: trialStartFileURL, encoding: .utf8) {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, let d = formatter.date(from: trimmed) {
                candidates.append(d)
            }
        }
        return candidates.min()
    }

    /// Writes the trial start date to every store, so a later launch can reconstruct
    /// it even if one store is cleared.
    private static func persistFirstLaunch(_ date: Date, keychain: KeychainStore) {
        let iso = ISO8601DateFormatter().string(from: date)
        keychain.set(iso, for: .firstLaunchDate)
        UserDefaults.standard.set(iso, forKey: trialStartDefaultsKey)
        let dir = trialStartFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? iso.write(to: trialStartFileURL, atomically: true, encoding: .utf8)
    }
}

private struct GumroadVerifyResponse: Decodable {
    let success: Bool
    let message: String?
    let purchase: Purchase?

    struct Purchase: Decodable {
        let email: String?
        let refunded: Bool?
        let chargebacked: Bool?
    }
}
