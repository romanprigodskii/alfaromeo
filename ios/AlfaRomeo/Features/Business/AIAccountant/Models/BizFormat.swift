import Foundation

/// Small ₽/date formatting helpers for the AI-accountant cards (§8.2). `AmountText` covers the big
/// figures; these cover inline strings inside sentences ("через 14 дней", "17 июня").
enum BizFormat {
    /// «1 200 000 ₽» via ``MoneyFormat`` (NBSP grouping, U+2212 minus, no kopecks).
    static func ruble(_ amount: Double) -> String {
        MoneyFormat.fiat(amount.rounded())
    }

    /// «1,2 млн ₽» / «980 тыс. ₽», compact for tight callouts (``MoneyFormat/compact(_:currency:)``).
    static func compactRuble(_ amount: Double) -> String {
        MoneyFormat.compact(amount)
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
