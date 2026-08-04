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
        if keychain.string(for: .firstLaunchDate) == nil {
            isFirstLaunch = true
            keychain.set(ISO8601DateFormatter().string(from: Date()), for: .firstLaunchDate)
        } else {
            isFirstLaunch = false
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
    /// only an explicit refunded/chargebacked/invalid response revokes it.
    private func revalidateCachedLicense() {
        guard let key = keychain.string(for: .licenseKey) else { return }
        verify(licenseKey: key, incrementUses: false) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                guard response.purchase?.refunded == true || response.purchase?.chargebacked == true else { return }
                self.keychain.remove(.licenseKey)
                self.keychain.remove(.licenseValidated)
                self.keychain.remove(.licenseEmail)
                DispatchQueue.main.async {
                    self.state = Self.computeState(keychain: self.keychain)
                }
            case .failure:
                break
            }
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
