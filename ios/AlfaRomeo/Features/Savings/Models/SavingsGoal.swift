import Foundation

/// A savings goal with a progress bar and optional auto-top-up (§10.6 "Цели с прогрессом и
/// авто-пополнением"). Mutable feature-local model — the API has no goals endpoint, so these live in
/// ``SavingsStore``.
struct SavingsGoal: Identifiable, Hashable, Sendable {
    let id: String
    let profileId: String
    var title: String
    var emoji: String
    var target: Double               // ₽
    var current: Double              // ₽
    var autoTopUpMonthly: Double?    // ₽/мес; nil = выключено

    var progress: Double { target > 0 ? min(current / target, 1) : 0 }
    var remaining: Double { max(target - current, 0) }
    var isComplete: Bool { current >= target && target > 0 }
    var autoTopUpEnabled: Bool { autoTopUpMonthly != nil }

    /// Months left to reach the target at the current auto-top-up rate (nil if auto-top-up is off).
    var monthsToTarget: Int? {
        guard let monthly = autoTopUpMonthly, monthly > 0, !isComplete else { return nil }
        return Int((remaining / monthly).rounded(.up))
    }
}
