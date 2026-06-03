import SwiftUI

/// Display helpers for profile types and tiers used by the switcher (§5).
extension ProfileType {
    var label: String {
        switch self {
        case .personal: return "Личный"
        case .business: return "Бизнес"
        case .joint:    return "Семейный"
        case .child:    return "Детский"
        }
    }

    var icon: String {
        switch self {
        case .personal: return "person.fill"
        case .business: return "briefcase.fill"
        case .joint:    return "person.2.fill"
        case .child:    return "figure.child"
        }
    }

    /// The context color marker (§5.2): personal — brand accent; business — graphite; child — soft.
    /// Light is the primary scheme (§13.1), so the swatch resolves its light-mode accent.
    var markerColor: Color {
        Theme.resolve(for: self, scheme: .light).accent
    }
}

extension SubscriptionTier {
    var shortLabel: String {
        switch self {
        case .base:     return "Base"
        case .pro:      return "Pro"
        case .infinite: return "Infinite"
        case .bizStart: return "Biz Старт"
        case .bizPro:   return "Biz Pro"
        case .bizCorp:  return "Biz Корп"
        }
    }
}
