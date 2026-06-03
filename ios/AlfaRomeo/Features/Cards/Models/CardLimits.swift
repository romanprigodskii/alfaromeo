import Foundation

/// Per-card spending limits (§6.3 "лимиты"). Demo values; editable in the limits sheet, with a
/// monthly-spend gauge feeding ``ProgressBar``.
struct CardLimits: Equatable, Hashable, Sendable {
    /// Max per single transaction, ₽.
    var perTransaction: Double
    /// Monthly spending cap, ₽.
    var monthly: Double
    /// Spent so far this month, ₽ (drives the progress gauge).
    var monthlySpent: Double
    var onlineEnabled: Bool
    var contactlessEnabled: Bool

    /// 0…1 fraction of the monthly cap used.
    var monthlyProgress: Double {
        guard monthly > 0 else { return 0 }
        return min(monthlySpent / monthly, 1)
    }

    /// Remaining monthly headroom, ₽ (never negative).
    var monthlyRemaining: Double { max(monthly - monthlySpent, 0) }

    /// A typical funded card.
    static let standard = CardLimits(perTransaction: 100_000, monthly: 500_000,
                                     monthlySpent: 184_500, onlineEnabled: true, contactlessEnabled: true)

    /// A fresh card with nothing spent yet.
    static let fresh = CardLimits(perTransaction: 100_000, monthly: 500_000,
                                  monthlySpent: 0, onlineEnabled: true, contactlessEnabled: true)

    /// A locked-down burner (low cap, contactless off — it's an online token).
    static func burner(limit: Double) -> CardLimits {
        CardLimits(perTransaction: limit, monthly: limit, monthlySpent: 0,
                   onlineEnabled: true, contactlessEnabled: false)
    }

    /// A child card (tight caps, §5.1 родительский контроль).
    static let child = CardLimits(perTransaction: 2_000, monthly: 10_000,
                                  monthlySpent: 4_200, onlineEnabled: true, contactlessEnabled: true)
}
