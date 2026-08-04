import Foundation

enum GumroadConfig {
    /// The API-facing product ID from the product's Content tab ("Use your product ID to
    /// verify licenses through the API") — distinct from the vanity URL slug below. Sent as
    /// the `product_id` param on /licenses/verify (this product doesn't accept the older
    /// `product_permalink` param name).
    static let productID = "utpPsS0tP-SnwEg9llUu-g=="

    /// `wanted=true` skips the product page and opens checkout directly.
    static let purchaseURL = URL(string: "https://lauron25.gumroad.com/l/LauronFlow?wanted=true")!
    static let verifyURL = URL(string: "https://api.gumroad.com/v2/licenses/verify")!
}
