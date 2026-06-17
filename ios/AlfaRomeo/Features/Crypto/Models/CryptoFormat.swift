import Foundation

/// Shared number formatting for the Crypto hub (§9.6). Mirrors the DS conventions used elsewhere
/// (thin-space grouping `U+2009`, real minus `U+2212`) so amounts read consistently with
/// ``AmountText`` and the Payments flows. Pure value helpers — no view state.
enum CryptoFormat {

    // MARK: ₽

    /// `1 234 567 ₽` — fiat amount, thin-space grouped, up to 2 fraction digits.
    static func rub(_ value: Double, fraction: Int = 0) -> String {
        let f = rubFormatter
        f.maximumFractionDigits = fraction
        let magnitude = f.string(from: NSNumber(value: abs(value))) ?? "\(Int(abs(value)))"
        let sign = value < 0 ? "\u{2212}" : ""
        return "\(sign)\(magnitude)\u{00A0}₽"
    }

    /// `1,2 млн ₽` / `320 тыс ₽` — compact, for chart axes and tight chips.
    static func compactRub(_ value: Double) -> String {
        let v = abs(value)
        let sign = value < 0 ? "\u{2212}" : ""
        if v >= 1_000_000 { return "\(sign)\(trim(v / 1_000_000)) млн ₽" }
        if v >= 1_000 { return "\(sign)\(Int((v / 1_000).rounded())) тыс ₽" }
        return "\(sign)\(Int(v.rounded())) ₽"
    }

    // MARK: $ (display denomination toggle, §9.6)

    /// `$1 234` — fiat amount in dollars, thin-space grouped (mirrors ``rub(_:fraction:)``).
    static func usd(_ value: Double, fraction: Int = 0) -> String {
        let f = rubFormatter
        f.maximumFractionDigits = fraction
        let magnitude = f.string(from: NSNumber(value: abs(value))) ?? "\(Int(abs(value)))"
        let sign = value < 0 ? "\u{2212}" : ""
        return "\(sign)$\(magnitude)"
    }

    /// `$1,2 млн` / `$320 тыс` — compact dollars (mirrors ``compactRub(_:)``).
    static func compactUsd(_ value: Double) -> String {
        let v = abs(value)
        let sign = value < 0 ? "\u{2212}" : ""
        if v >= 1_000_000 { return "\(sign)$\(trim(v / 1_000_000)) млн" }
        if v >= 1_000 { return "\(sign)$\(Int((v / 1_000).rounded())) тыс" }
        return "\(sign)$\(Int(v.rounded()))"
    }

    // MARK: Denomination-aware (₽/$ toggle)

    /// Render a **₽-denominated** amount in the chosen display currency. In `.usd` the ₽ value is
    /// divided by the live `usdRub` rate (``LivePriceService/usdRub``). Stored values stay in ₽ —
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

    /// Asset units with sensible precision per magnitude (e.g. `0,1423 BTC`, `1 820,40 USDT`).
    static func qty(_ value: Double, symbol: String? = nil) -> String {
        let f = qtyFormatter
        f.maximumFractionDigits = fractionDigits(for: value)
        let s = f.string(from: NSNumber(value: value)) ?? "\(value)"
        if let symbol { return "\(s) \(symbol)" }
        return s
    }

    /// Digits to show for a balance: more for small fractional crypto, fewer for large balances.
    static func fractionDigits(for value: Double) -> Int {
        let v = abs(value)
        switch v {
        case 0:            return 0
        case ..<1:         return 6
        case ..<100:       return 4
        case ..<10_000:    return 2
        default:           return 2
        }
    }

    // MARK: Percent

    /// `+2,4 %` / `−1,1 %` with a real minus and a leading plus.
    static func pct(_ value: Double, fraction: Int = 2) -> String {
        let f = pctFormatter
        f.maximumFractionDigits = fraction
        let magnitude = f.string(from: NSNumber(value: abs(value))) ?? "\(abs(value))"
        let sign = value < 0 ? "\u{2212}" : "+"
        return "\(sign)\(magnitude) %"
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

    private static func trim(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }

    private static let rubFormatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.groupingSeparator = "\u{00A0}"; f.minimumFractionDigits = 0  // NBSP — visible group gap in the proportional amount font
        return f
    }()
    private static let qtyFormatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.groupingSeparator = "\u{00A0}"; f.minimumFractionDigits = 0  // NBSP — visible group gap in the proportional amount font
        return f
    }()
    private static let pctFormatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        return f
    }()
    private static let plainFormatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.usesGroupingSeparator = false; f.maximumFractionDigits = 8
        return f
    }()
}
