import Foundation

/// Tier-aware rate engine (§4): top tiers earn a higher deposit rate and **premium staking APY**.
///
/// Derived entirely in-feature from the active ``Tier`` (read via `AppSession.currentTier`) — the
/// shared `Entitlements`/Core models are left untouched. The boost is expressed in *percentage
/// points* added to a product's `baseApy`, keyed off `Tier.rank` (0 = Base/Старт, 1 = Pro,
/// 2 = Infinite/Корп), so the premium reads honestly on the card ("+1.5 п.п. на Infinite").
enum SavingsRates {
    // Percentage-point uplift by tier rank.
    private static let depositBoostByRank: [Double] = [0, 0.7, 1.5]   // Base, Pro, Infinite
    private static let stakeBoostByRank: [Double]   = [0, 1.0, 2.0]

    static func depositBoost(for tier: Tier) -> Double { depositBoostByRank[clamp(tier.rank)] }
    static func stakeBoost(for tier: Tier) -> Double { stakeBoostByRank[clamp(tier.rank)] }

    /// Effective deposit rate (%) for a product at the given tier.
    static func depositApy(base: Double, tier: Tier) -> Double { base + depositBoost(for: tier) }

    /// Effective staking APY (%) for a product at the given tier.
    static func stakeApy(base: Double, tier: Tier) -> Double { base + stakeBoost(for: tier) }

    /// Whether this tier already receives the top premium APY (§4: Infinite/Корп).
    static func hasPremiumApy(_ tier: Tier) -> Bool { tier.rank >= 2 }

    /// Extra staking APY still unlockable by upgrading to the top tier (drives the upsell copy).
    static func stakeUpliftToTop(from tier: Tier) -> Double {
        stakeBoostByRank[2] - stakeBoost(for: tier)
    }

    /// Extra deposit rate still unlockable by upgrading to the top tier.
    static func depositUpliftToTop(from tier: Tier) -> Double {
        depositBoostByRank[2] - depositBoost(for: tier)
    }

    private static func clamp(_ rank: Int) -> Int { min(max(rank, 0), 2) }
}
