import Foundation

/// Кэшбек гигабайтами (§7.1): «траты по карте → ГБ». `earnedGb` is accrued and can be credited into
/// the active package; `creditedGb` is the bonus already added to the data cap; `perMonthGb` is the
/// tier-linked accrual rate.
struct MobileCashback: Hashable, Sendable {
    var earnedGb: Double
    var creditedGb: Double
    var perMonthGb: Double

    var hasEarned: Bool { earnedGb >= 0.1 }

    private static func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
    var earnedLabel: String { Self.fmt(earnedGb) + " ГБ" }
    var perMonthLabel: String { "≈ " + Self.fmt(perMonthGb) + " ГБ/мес" }
    var creditedLabel: String { Self.fmt(creditedGb) + " ГБ" }
}
