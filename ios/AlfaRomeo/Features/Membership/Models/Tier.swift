import Foundation

/// The membership tier is the contract's ``SubscriptionTier`` (base/pro/infinite + business).
typealias Tier = SubscriptionTier

extension SubscriptionTier {
    var displayName: String {
        switch self {
        case .base:     return "Ромео Base"
        case .pro:      return "Ромео Pro"
        case .infinite: return "Ромео Infinite"
        case .bizStart: return "Бизнес Старт"
        case .bizPro:   return "Бизнес Pro"
        case .bizCorp:  return "Бизнес Корп"
        }
    }

    var priceLabel: String {
        switch self {
        case .base, .bizStart: return "Бесплатно"
        case .pro:             return "₽ / мес"
        case .infinite:        return "₽₽₽ / мес"
        case .bizPro:          return "₽₽ / мес"
        case .bizCorp:         return "₽₽₽ / мес"
        }
    }

    var isBusiness: Bool {
        switch self {
        case .bizStart, .bizPro, .bizCorp: return true
        default: return false
        }
    }

    /// Rank within a track (personal or business), 0…2 — used to label upgrade vs downgrade.
    var rank: Int {
        switch self {
        case .base, .bizStart: return 0
        case .pro, .bizPro:    return 1
        case .infinite, .bizCorp: return 2
        }
    }

    static let personalTiers: [SubscriptionTier] = [.base, .pro, .infinite]
    static let businessTiers: [SubscriptionTier] = [.bizStart, .bizPro, .bizCorp]

    /// The comparable tier set for a profile type (§4.1 personal / §4.2 business).
    static func track(forBusiness business: Bool) -> [SubscriptionTier] {
        business ? businessTiers : personalTiers
    }
}
