import Foundation

/// Shared number formatting for the Crypto hub (§9.6). Every on-screen number goes through the
/// design-system ``MoneyFormat`` (docs/DESIGN.md §6); this enum only adds the ₽/$ denomination and
/// per-magnitude quantity precision. Pure value helpers, no view state.
enum CryptoFormat {

    // MARK: ₽

    /// `1 234 567 ₽`: fiat amount via ``MoneyFormat`` (NBSP grouping, decimal comma, U+2212 minus).
    /// `fraction: 0` rounds to whole roubles (live-ticking totals); otherwise the fiat rule applies
    /// (whole → no decimals, else exactly two).
    static func rub(_ value: Double, fraction: Int = 0) -> String {
        MoneyFormat.fiat(fraction == 0 ? value.rounded() : value)
    }

    /// `1,2 млн ₽` / `320 тыс. ₽`: compact, for chart axes and tight summaries.
    static func compactRub(_ value: Double) -> String {
        MoneyFormat.compact(value)
    }

    // MARK: $ (display denomination toggle, §9.6)

    /// `1 234 $`: fiat amount in dollars (mirrors ``rub(_:fraction:)``).
    static func usd(_ value: Double, fraction: Int = 0) -> String {
        MoneyFormat.fiat(fraction == 0 ? value.rounded() : value, currency: "$")
    }

    /// `1,2 млн $` / `320 тыс. $`: compact dollars (mirrors ``compactRub(_:)``).
    static func compactUsd(_ value: Double) -> String {
        MoneyFormat.compact(value, currency: "$")
    }

    // MARK: Denomination-aware (₽/$ toggle)

    /// Render a **₽-denominated** amount in the chosen display currency. In `.usd` the ₽ value is
    /// divided by the live `usdRub` rate (``LivePriceService/usdRub``). Stored values stay in ₽,
    /// display only (§9.6).
    static func money(_ rub: Double, denom: PortfolioDenomination, usdRub: Double, fraction: Int = 0) -> String {
        switch denom {
        case .rub: return self.rub(rub, fraction: fraction)
        case .usd: return usd(usdRub > 0 ? rub / usdRub : 0, fraction: fraction)
        }
    }

    /// Compact denomination-aware amount for chips / breakdowns.
    static func compactMoney(_ rub: Double, denom: PortfolioDenomination, usdRub: Double) -> String {
        switch denom {
        case .rub: return compactRub(rub)
        case .usd: return compactUsd(usdRub > 0 ? rub / usdRub : 0)
        }
    }

    // MARK: Asset quantity

    /// Asset units via ``MoneyFormat/crypto(_:symbol:maxFractionDigits:sign:)``, zeros trimmed, with
    /// precision capped per magnitude (`0,1423 BTC`, `1 820,4 USDT`).
    static func qty(_ value: Double, symbol: String? = nil) -> String {
        MoneyFormat.crypto(value, symbol: symbol, maxFractionDigits: fractionDigits(for: value))
    }

    /// Digits to show for a balance: more for small fractional crypto, fewer for large balances.
    static func fractionDigits(for value: Double) -> Int {
        let v = abs(value)
        switch v {
        case 0:            return 0
        case ..<1:         return 6
        case ..<100:       return 4
        default:           return 2
        }
    }

    // MARK: Percent

    /// `+2,4 %` / `−1,1 %`: always signed, real minus, NBSP before `%`.
    static func pct(_ value: Double, fraction: Int = 2) -> String {
        MoneyFormat.percent(value, maxFractionDigits: fraction, sign: .always)
    }

    /// A plain, ungrouped editable string for seeding amount fields (locale decimal separator).
    static func plain(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return plainFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Parse a user-entered amount string (thin spaces / commas tolerated).
    static func parse(_ text: String) -> Double {
        let cleaned = text
            .replacingOccurrences(of: "\u{2009}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")   // NBSP group separator
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 0
    }

    // MARK: - Private

    private static let plainFormatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.usesGroupingSeparator = false; f.maximumFractionDigits = 8
        return f
    }()
}
