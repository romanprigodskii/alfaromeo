import Foundation

/// Кэшбек гигабайтами (§7.1): «траты по карте → ГБ». `earnedGb` is accrued and can be credited into
/// the active package; `creditedGb` is the bonus already added to the data cap; `perMonthGb` is the
/// tier-linked accrual rate.
struct MobileCashback: Hashable, Sendable {
    var earnedGb: Double
    var creditedGb: Double
    var perMonthGb: Double

    var hasEarned: Bool { earnedGb >= 0.1 }

    private static func fmt(_ v: Double) -> String { MobileTariff.format(v) }
    var earnedLabel: String { Self.fmt(earnedGb) + "\u{00A0}ГБ" }
    var perMonthLabel: String { "≈\u{00A0}" + Self.fmt(perMonthGb) + "\u{00A0}ГБ в месяц" }
    var creditedLabel: String { Self.fmt(creditedGb) + "\u{00A0}ГБ" }
}
