import Foundation

/// Tier privileges as feature-flags + limits (§4.1 matrix). Derived from a ``Tier`` and read
/// across the UI to gate features (no separate screens per tier — §4 "feature flags + лимиты").
struct Entitlements: Equatable, Sendable {
    enum CashbackLevel: String { case basic, raised, max
        var label: String {
            switch self {
            case .basic:  return "Базовый, 1 категория"
            case .raised: return "Повышенный, супер-кэшбек"
            case .max:    return "Максимальный, все категории"
            }
        }
    }
    enum SpreadTier: String { case standard, reduced, minimal
        var label: String {
            switch self {
            case .standard: return "Обычный спред"
            case .reduced:  return "Сниженный спред"
            case .minimal:  return "Минимальный спред"
            }
        }
    }
    enum MobilePackage: String { case s, m, unlimited
        var label: String {
            switch self {
            case .s:         return "Пакет S"
            case .m:         return "Пакет M + роуминг"
            case .unlimited: return "Безлимит + роуминг"
            }
        }
    }
    enum SupportLevel: String { case standard, priority, concierge
        var label: String {
            switch self {
            case .standard:  return "Стандарт: AI и очередь"
            case .priority:  return "Приоритет"
            case .concierge: return "Консьерж 24/7"
            }
        }
    }
    enum TravelPerks: String { case none, partner, full
        var label: String {
            switch self {
            case .none:    return "Нет"
            case .partner: return "Скидки у партнёров"
            case .full:    return "Лаунж, страховка, консьерж"
            }
        }
    }

    let tier: Tier
    let cashback: CashbackLevel
    let maxCards: Int?          // nil = без лимита
    let cryptoSpread: SpreadTier
    let aiRequestsPerDay: Int?  // nil = без лимита
    let mobilePackage: MobilePackage
    let support: SupportLevel
    let freeAbroadTransfers: Bool
    let cryptoTransfers: Bool
    let allCashbackCategories: Bool
    let travel: TravelPerks
    let proactiveAI: Bool

    var maxCardsLabel: String { maxCards.map(String.init) ?? "∞" }
    var aiLimitLabel: String { aiRequestsPerDay.map { "\($0) в день" } ?? "Без лимита" }

    /// Gating helper: can the profile have one more card at this tier?
    func canAddCard(currentCount: Int) -> Bool {
        guard let maxCards else { return true }
        return currentCount < maxCards
    }

    /// Build the entitlements for a tier (§4.1 personal, §4.2 business — approximated).
    static func make(for tier: Tier) -> Entitlements {
        switch tier {
        case .base:
            return Entitlements(tier: tier, cashback: .basic, maxCards: 1, cryptoSpread: .standard,
                                aiRequestsPerDay: 20, mobilePackage: .s, support: .standard,
                                freeAbroadTransfers: false, cryptoTransfers: false,
                                allCashbackCategories: false, travel: .none, proactiveAI: false)
        case .pro:
            return Entitlements(tier: tier, cashback: .raised, maxCards: 3, cryptoSpread: .reduced,
                                aiRequestsPerDay: nil, mobilePackage: .m, support: .priority,
                                freeAbroadTransfers: true, cryptoTransfers: true,
                                allCashbackCategories: false, travel: .partner, proactiveAI: false)
        case .infinite:
            return Entitlements(tier: tier, cashback: .max, maxCards: nil, cryptoSpread: .minimal,
                                aiRequestsPerDay: nil, mobilePackage: .unlimited, support: .concierge,
                                freeAbroadTransfers: true, cryptoTransfers: true,
                                allCashbackCategories: true, travel: .full, proactiveAI: true)
        case .bizStart:
            return Entitlements(tier: tier, cashback: .basic, maxCards: 2, cryptoSpread: .standard,
                                aiRequestsPerDay: 20, mobilePackage: .s, support: .standard,
                                freeAbroadTransfers: false, cryptoTransfers: false,
                                allCashbackCategories: false, travel: .none, proactiveAI: false)
        case .bizPro:
            return Entitlements(tier: tier, cashback: .raised, maxCards: 10, cryptoSpread: .reduced,
                                aiRequestsPerDay: nil, mobilePackage: .m, support: .priority,
                                freeAbroadTransfers: true, cryptoTransfers: true,
                                allCashbackCategories: false, travel: .partner, proactiveAI: false)
        case .bizCorp:
            return Entitlements(tier: tier, cashback: .max, maxCards: nil, cryptoSpread: .minimal,
                                aiRequestsPerDay: nil, mobilePackage: .unlimited, support: .concierge,
                                freeAbroadTransfers: true, cryptoTransfers: true,
                                allCashbackCategories: true, travel: .full, proactiveAI: true)
        }
    }
}
