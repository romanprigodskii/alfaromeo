import Foundation

// Mirror of /shared (CryptoWallet, §11.3) — keep in sync until codegen (Phase 0.3).

/// A per-asset crypto wallet scoped to a profile.
struct CryptoWallet: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let profileId: String
    let asset: String     // BTC, ETH, USDT, …
    let chain: String     // bitcoin, ethereum, tron, …
    let address: String
    let balance: Double    // in asset units
}
