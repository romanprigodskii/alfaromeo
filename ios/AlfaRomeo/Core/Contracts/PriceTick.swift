import Foundation

// Mirror of /shared (PriceTick, §11.3/§11.4) — keep in sync until codegen (Phase 0.3).

/// A price point for an asset. `price` is the unified ₽ equivalent (§11.4); REST snapshots come
/// from ``APIClient/prices(assets:)`` and the live stream from ``PriceSocket``.
struct PriceTick: Codable, Identifiable, Hashable, Sendable {
    let asset: String        // BTC, ETH, USDT, …
    let price: Double         // ₽
    var changePct24h: Double?
    let ts: String            // ISO-8601

    var id: String { "\(asset)-\(ts)" }
}
