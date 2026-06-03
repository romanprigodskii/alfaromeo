import Foundation

/// Maps the tier's ``Entitlements/SpreadTier`` to a concrete spread percentage. Membership only
/// models the *qualitative* tier (standard/reduced/minimal) — the Crypto module owns the numbers
/// (§4: Pro/Infinite get a lower spread). Used by every buy/sell/convert preview.
enum CryptoSpread {
    static func pct(for tier: Entitlements.SpreadTier) -> Double {
        switch tier {
        case .standard: return 0.015   // 1.5 %
        case .reduced:  return 0.0075  // 0.75 %
        case .minimal:  return 0.004   // 0.4 %
        }
    }

    /// `0,75 %` for display.
    static func label(for tier: Entitlements.SpreadTier) -> String {
        CryptoFormat.pct(pct(for: tier) * 100, fraction: 2)
    }
}

/// Which way a quote runs.
enum CryptoSide: String, Hashable, Sendable { case buy, sell }

/// A live, time-boxed quote for a crypto operation (§10.8 «re-quote с TTL»). The mid price is the live
/// ₽ rate from ``LivePriceService``; the effective `rate` folds in the tier spread. The quote expires
/// after `ttl` seconds — the confirm step counts down and forces a re-quote on expiry so the user
/// never executes at a stale rate during volatility.
struct CryptoQuote: Hashable, Sendable {
    let asset: String
    let side: CryptoSide
    let midPriceRub: Double
    let spreadPct: Double
    let createdAt: Date
    var ttl: TimeInterval = 20

    /// Effective ₽ rate per unit, including spread (buyer pays more, seller receives less).
    var rate: Double {
        side == .buy ? midPriceRub * (1 + spreadPct) : midPriceRub * (1 - spreadPct)
    }

    var expiresAt: Date { createdAt.addingTimeInterval(ttl) }
    func remaining(at now: Date) -> TimeInterval { max(0, expiresAt.timeIntervalSince(now)) }
    func isExpired(at now: Date) -> Bool { now >= expiresAt }

    /// The ₽ spread cost for a given asset quantity (informational).
    func spreadCostRub(qty: Double) -> Double { abs(rate - midPriceRub) * qty }
}
