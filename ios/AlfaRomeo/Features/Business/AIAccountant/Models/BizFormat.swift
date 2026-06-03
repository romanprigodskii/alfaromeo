import Foundation

/// Small ₽/date formatting helpers for the AI-accountant cards (§8.2). `AmountText` covers the big
/// monospaced figures; these cover inline strings inside sentences ("через 14 дней", "17 июня").
enum BizFormat {
    private static let rubFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{2009}" // thin space
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    /// "1 200 000 ₽" (thin-space grouped, no decimals).
    static func ruble(_ amount: Double) -> String {
        let n = rubFormatter.string(from: NSNumber(value: abs(amount))) ?? "\(Int(abs(amount)))"
        let sign = amount < 0 ? "\u{2212}" : ""
        return "\(sign)\(n) ₽"
    }

    /// "1,2 млн ₽" / "980 тыс ₽" — compact, for tight callouts.
    static func compactRuble(_ amount: Double) -> String {
        let sign = amount < 0 ? "\u{2212}" : ""
        let v = abs(amount)
        if v >= 1_000_000 { return sign + String(format: "%.1f млн ₽", v / 1_000_000).replacingOccurrences(of: ".", with: ",") }
        if v >= 1_000 { return sign + String(format: "%.0f тыс ₽", v / 1_000) }
        return sign + String(format: "%.0f ₽", v)
    }

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.setLocalizedDateFormatFromTemplate("d MMMM")
        return f
    }()

    /// "17 июня" — the cash-gap date in Russian.
    static func dayMonth(_ date: Date) -> String {
        dayMonthFormatter.string(from: date)
    }

    /// "через 14 дней" with correct plural (день/дня/дней).
    static func inDays(_ days: Int) -> String {
        "через \(days) \(pluralDays(days))"
    }

    static func pluralDays(_ n: Int) -> String {
        let mod100 = n % 100
        let mod10 = n % 10
        if mod100 >= 11 && mod100 <= 14 { return "дней" }
        switch mod10 {
        case 1: return "день"
        case 2, 3, 4: return "дня"
        default: return "дней"
        }
    }

    /// "4 счёта" / "1 счёт" / "5 счетов" — correct plural for the account count.
    static func accounts(_ n: Int) -> String {
        let mod100 = n % 100
        let mod10 = n % 10
        let noun: String
        if mod100 >= 11 && mod100 <= 14 { noun = "счетов" }
        else { switch mod10 { case 1: noun = "счёт"; case 2, 3, 4: noun = "счёта"; default: noun = "счетов" } }
        return "\(n) \(noun)"
    }
}
