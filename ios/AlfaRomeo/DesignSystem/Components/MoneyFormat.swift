import Foundation

/// The central Russian number formatter (docs/DESIGN.md §6). Use it for every amount, rate and
/// quantity on screen; no ad-hoc `String(format:)` in features.
///
/// - Groups with NBSP (U+00A0), decimal comma: `1 119 200,50 ₽`, NBSP before the currency sign.
/// - Fiat: 0 decimals when whole, otherwise exactly 2 (never `184 200,5`).
/// - Minus is U+2212; percent is `−0,74 %` (NBSP before `%`).
/// - Crypto qty: up to 8 decimals, trailing zeros trimmed: `0,1423 BTC`.
///
/// Locale-independent by construction (the device language never turns the comma into a dot).
enum MoneyFormat {
    static let nbsp = "\u{00A0}"
    static let minus = "\u{2212}"

    /// How the sign is rendered.
    enum Sign: Sendable {
        /// `−` for negatives only.
        case auto
        /// `+` for positives, `−` for negatives (signed operation amounts).
        case always
        /// Magnitude only.
        case never
    }

    // MARK: - Amounts

    /// Fiat amount: `1 119 200,50 ₽`, `12 400 ₽`. `currency` may be a sign (`₽`) or an ISO code (`RUB`).
    static func fiat(_ amount: Double, currency: String = "₽", sign: Sign = .auto) -> String {
        let body = fiatDigits(abs(amount))
        return signPrefix(amount, isZero: body.isZeroValue, sign) + body.text + suffix(currency)
    }

    /// Signed operation amount: `+12 400 ₽`, `−1 240,50 ₽`.
    static func signed(_ amount: Double, currency: String = "₽") -> String {
        self.amount(amount, currency: currency, sign: .always)
    }

    /// Amount in any currency: crypto tickers use ``crypto(_:symbol:maxFractionDigits:sign:)``,
    /// everything else (incl. stablecoins) uses the fiat rule.
    static func amount(_ amount: Double, currency: String = "₽", sign: Sign = .auto) -> String {
        isCryptoTicker(currency)
            ? crypto(amount, symbol: currency.uppercased(), sign: sign)
            : fiat(amount, currency: currency, sign: sign)
    }

    /// Crypto quantity: `0,1423 BTC`, `12,5 ETH`. Up to `maxFractionDigits` decimals, zeros trimmed.
    static func crypto(_ qty: Double, symbol: String? = nil, maxFractionDigits: Int = 8,
                       sign: Sign = .auto) -> String {
        let body = digits(abs(qty), minFraction: 0, maxFraction: maxFractionDigits)
        let tail = symbol.map { nbsp + $0 } ?? ""
        return signPrefix(qty, isZero: body.isZeroValue, sign) + body.text + tail
    }

    /// Plain number with Russian grouping and decimal comma.
    static func number(_ value: Double, minFractionDigits: Int = 0, maxFractionDigits: Int = 2,
                       sign: Sign = .auto) -> String {
        let body = digits(abs(value), minFraction: minFractionDigits, maxFraction: maxFractionDigits)
        return signPrefix(value, isZero: body.isZeroValue, sign) + body.text
    }

    /// Integer with grouping: `24`, `1 500`.
    static func integer(_ value: Int) -> String {
        (value < 0 ? minus : "") + group(String(value.magnitude))
    }

    // MARK: - Percent

    /// Percent from percentage points: `percent(19.9)` → `19,9 %`, `percent(-0.74)` → `−0,74 %`,
    /// `percent(26)` → `26 %`. Trailing zeros are trimmed down to `minFractionDigits`.
    static func percent(_ points: Double, minFractionDigits: Int = 0, maxFractionDigits: Int = 2,
                        sign: Sign = .auto) -> String {
        number(points, minFractionDigits: minFractionDigits, maxFractionDigits: maxFractionDigits,
               sign: sign) + nbsp + "%"
    }

    /// Percent from a fraction: `percent(fraction: 0.199)` → `19,9 %`.
    static func percent(fraction: Double, minFractionDigits: Int = 0, maxFractionDigits: Int = 2,
                        sign: Sign = .auto) -> String {
        percent(fraction * 100, minFractionDigits: minFractionDigits,
                maxFractionDigits: maxFractionDigits, sign: sign)
    }

    // MARK: - Compact

    /// Compact amount for limits and summaries: `2,2 млн ₽`, `840 тыс. ₽`, `1,5 млрд ₽`.
    /// Below 10 000 the full fiat form is used. Pass `currency: nil` for a bare number.
    static func compact(_ amount: Double, currency: String? = "₽") -> String {
        let m = abs(amount)
        let scaled: (Double, String)?
        // Thresholds sit at the rounding edge (999,5 of the smaller unit), so 999 999 reads «1 млн», never «1 000 тыс.».
        switch m {
        case 999_500_000...:   scaled = (m / 1_000_000_000, "млрд")
        case 999_500...:       scaled = (m / 1_000_000, "млн")
        case 10_000...:        scaled = (m / 1_000, "тыс.")
        default:               scaled = nil
        }
        guard let (value, unit) = scaled else {
            if let currency { return fiat(amount, currency: currency) }
            return number(amount)
        }
        let body = digits(value, minFraction: 0, maxFraction: value < 100 ? 1 : 0)
        let cur = currency.map { nbsp + symbol(for: $0) } ?? ""
        return signPrefix(amount, isZero: body.isZeroValue, .auto) + body.text + nbsp + unit + cur
    }

    // MARK: - Hero parts

    /// Splits a fiat amount for the hero style: `("1 119 200", ",50")`, `("12 400", nil)`.
    /// The sign (if any) is part of `integer`.
    static func parts(_ amount: Double, sign: Sign = .auto) -> (integer: String, fraction: String?) {
        let body = fiatDigits(abs(amount))
        let prefix = signPrefix(amount, isZero: body.isZeroValue, sign)
        if let comma = body.text.firstIndex(of: ",") {
            return (prefix + String(body.text[..<comma]), String(body.text[comma...]))
        }
        return (prefix + body.text, nil)
    }

    // MARK: - Currency

    /// Display sign for an ISO code: `RUB` → `₽`, `USD` → `$`, `EUR` → `€`. Unknown codes and signs
    /// pass through unchanged (`USDT`, `₽`).
    static func symbol(for code: String) -> String {
        switch code.uppercased() {
        case "RUB", "RUR": return "₽"
        case "USD":        return "$"
        case "EUR":        return "€"
        case "CNY":        return "¥"
        case "GBP":        return "£"
        case "DRUB":       return "Ц₽"
        default:           return code
        }
    }

    /// Volatile crypto assets (quantity formatting). Stablecoins (USDT, USDC, DAI) are fiat-like.
    static func isCryptoTicker(_ code: String) -> Bool {
        cryptoTickers.contains(code.uppercased())
    }

    private static let cryptoTickers: Set<String> = [
        "BTC", "ETH", "SOL", "TON", "XRP", "BNB", "ADA", "DOGE", "DOT", "TRX", "LTC", "AVAX", "MATIC",
        "LINK", "ATOM", "NOT", "XMR", "BCH",
    ]

    // MARK: - Internals

    private struct Digits {
        let text: String
        let isZeroValue: Bool
    }

    private static func suffix(_ currency: String) -> String {
        currency.isEmpty ? "" : nbsp + symbol(for: currency)
    }

    private static func signPrefix(_ value: Double, isZero: Bool, _ sign: Sign) -> String {
        guard !isZero else { return "" }
        switch sign {
        case .never:  return ""
        case .auto:   return value < 0 ? minus : ""
        case .always: return value < 0 ? minus : "+"
        }
    }

    /// Fiat rule: whole → no decimals, otherwise exactly two.
    private static func fiatDigits(_ magnitude: Double) -> Digits {
        let two = digits(magnitude, minFraction: 2, maxFraction: 2)
        if two.text.hasSuffix(",00") {
            return Digits(text: String(two.text.dropLast(3)), isZeroValue: two.isZeroValue)
        }
        return two
    }

    private static func digits(_ magnitude: Double, minFraction: Int, maxFraction: Int) -> Digits {
        guard magnitude.isFinite else { return Digits(text: "—", isZeroValue: true) }
        let maxF = max(0, min(maxFraction, 12))
        let minF = max(0, min(minFraction, maxF))
        let raw = String(format: "%.\(maxF)f", locale: Locale(identifier: "en_US_POSIX"), magnitude)
        let pieces = raw.split(separator: ".", maxSplits: 1)
        let intPart = String(pieces.first ?? "0")
        var frac = pieces.count > 1 ? String(pieces[1]) : ""
        while frac.count > minF, frac.last == "0" { frac.removeLast() }
        let isZero = intPart.allSatisfy { $0 == "0" } && frac.allSatisfy { $0 == "0" }
        return Digits(text: group(intPart) + (frac.isEmpty ? "" : "," + frac), isZeroValue: isZero)
    }

    /// Inserts NBSP every three digits from the right.
    private static func group(_ digits: String) -> String {
        guard digits.count > 3 else { return digits }
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0, (digits.count - i) % 3 == 0 { out.append(nbsp) }
            out.append(ch)
        }
        return out
    }
}
