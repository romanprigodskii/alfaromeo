import Foundation

/// Aggregated, profile-scoped snapshot powering the Главный dashboard (§9.1, §10.2).
///
/// Built by ``HomeViewModel`` from a single fan-out of profile-scoped ``APIClient`` calls, then read
/// by the dashboard sections. The derived ₽ figures fold in live ``PriceSocket`` ticks so the unified
/// ₽-equivalent and the crypto valuation update in real time (§11.4).
struct HomeDashboard {
    let profileId: String
    let profileType: ProfileType
    let accounts: [Account]
    let cards: [Card]
    let cardOrders: [CardOrder]
    let wallets: [CryptoWallet]
    let deposits: [Deposit]
    let mobilePlan: MobilePlan?
    let tier: SubscriptionTier

    /// REST ₽ snapshot (asset → ₽) — the fallback used until a live tick arrives (§11.4).
    let priceSnapshot: [String: Double]

    // MARK: Derived — fiat

    /// Sum of all ₽ balances (current + savings + digital ruble). The crypto *account* is valued via
    /// ``wallets`` instead, so it is intentionally excluded here to avoid double counting.
    var fiatRub: Double {
        accounts.filter { $0.currency == "RUB" }.reduce(0) { $0 + $1.balance }
    }

    // MARK: Derived — crypto (live)

    /// ₽ price for an asset: a live tick if present, else the REST snapshot, else 0.
    func price(for asset: String, live: [String: Double]) -> Double {
        live[asset.uppercased()] ?? priceSnapshot[asset.uppercased()] ?? 0
    }

    /// Total ₽ valuation of the crypto wallets at current prices.
    func cryptoValueRub(live: [String: Double]) -> Double {
        wallets.reduce(0) { $0 + $1.balance * price(for: $1.asset, live: live) }
    }

    /// The single ₽-equivalent shown in the header (§10.2): fiat + crypto.
    func unifiedTotalRub(live: [String: Double]) -> Double {
        fiatRub + cryptoValueRub(live: live)
    }

    // MARK: Derived — savings (§10.6)

    var bestDepositApy: Double? { deposits.map(\.rateApy).max() }

    /// ₽ value of savings: ruble deposits at principal; stakes valued via the snapshot price.
    var depositsValueRub: Double {
        deposits.reduce(0) { total, deposit in
            switch deposit.kind {
            case .ruble:
                return total + deposit.principal
            case .stake:
                let unit = priceSnapshot[(deposit.asset ?? "").uppercased()] ?? 0
                return total + deposit.principal * unit
            }
        }
    }

    // MARK: Derived — credit teaser (§10.5)

    /// Pre-approved credit line — a deterministic teaser (no credit endpoint this phase). Adults only.
    var preApprovedCredit: Double? {
        switch profileType {
        case .personal, .joint: return 1_200_000
        case .business, .child: return nil
        }
    }

    // MARK: States

    /// No money objects at all → the onboarding empty state (§10.2).
    var isEmpty: Bool { accounts.isEmpty && cards.isEmpty && wallets.isEmpty }

    /// The in-flight physical-card delivery, if any (mock logistics, §6.2).
    var pendingCardDelivery: CardOrder? {
        cardOrders.first { $0.physicalStatus != .none && $0.physicalStatus != .delivered }
    }
}
