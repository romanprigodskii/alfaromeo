import Foundation

// Кредиты (§10.5) — витрина продуктов: наличные / карта / рассрочка. The shelf below is the demo
// product range; the personalised rate inside each band is set by the pre-qual score, and рассрочка
// is fixed 0% (the math core treats it as straight-line).

/// Kind of credit product on the shelf (§10.5).
enum CreditKind: String, Sendable, CaseIterable {
    case cash         // кредит наличными
    case card         // кредитная карта (грейс-период)
    case installment  // рассрочка (POS, 0%)

    var title: String {
        switch self {
        case .cash:        return "Наличными"
        case .card:        return "Кредитная карта"
        case .installment: return "Рассрочка"
        }
    }
    var systemImage: String {
        switch self {
        case .cash:        return "banknote"
        case .card:        return "creditcard"
        case .installment: return "calendar.badge.clock"
        }
    }
    var amountNoun: String {              // hero/label wording per kind
        switch self {
        case .cash:        return "Сумма кредита"
        case .card:        return "Кредитный лимит"
        case .installment: return "Сумма покупки"
        }
    }
    /// Рассрочка is 0% — the math core treats it as straight-line (платёж = сумма ÷ срок).
    var isInterestFree: Bool { self == .installment }
}

/// A credit-product template (ставка-диапазон / срок / преодобрено, §10.5).
struct CreditProduct: Identifiable, Hashable, Sendable {
    let id: String
    let kind: CreditKind
    let name: String
    let tagline: String
    let minRate: Double            // годовых, %
    let maxRate: Double
    let termOptionsMonths: [Int]   // selectable terms
    let maxAmount: Double          // верхняя граница продукта (до пре-квалификации)
    let highlights: [String]

    var rateLabel: String { kind.isInterestFree ? "0%" : "от \(CreditFormat.rate(minRate))" }
    /// Default to the longest term — it gives the lowest, affordable payment and is consistent with
    /// how the approved limit is capitalised (at the reference term), so the default never shows an
    /// over-capacity payment.
    var defaultTerm: Int { termOptionsMonths.last ?? 12 }
    /// Floor of a sensible application amount.
    var minAmount: Double { kind == .installment ? 3_000 : 10_000 }
}

enum CreditCatalog {
    static let products: [CreditProduct] = [
        CreditProduct(
            id: "cr_cash", kind: .cash, name: "Кредит наличными",
            tagline: "Деньги на счёт за пару минут — без залога и поручителей",
            minRate: 18.9, maxRate: 39.9, termOptionsMonths: [6, 12, 24, 36, 48, 60],
            maxAmount: 5_000_000,
            highlights: ["Без справок до 1 млн ₽", "Досрочное погашение без штрафа", "Ставка зависит от истории"]),
        CreditProduct(
            id: "cr_card", kind: .card, name: "Кредитная карта 120",
            tagline: "Грейс-период 120 дней, кешбэк на тарифе Ромео",
            minRate: 24.9, maxRate: 49.9, termOptionsMonths: [6, 12, 24],
            maxAmount: 1_000_000,
            highlights: ["Грейс 120 дней без %", "Снятие наличных без комиссии", "Лимит растёт с историей"]),
        CreditProduct(
            id: "cr_installment", kind: .installment, name: "Рассрочка 0%",
            tagline: "Покупки у партнёров частями — без переплаты",
            minRate: 0, maxRate: 0, termOptionsMonths: [3, 6, 10, 12],
            maxAmount: 600_000,
            highlights: ["0% и без комиссий", "Платёж = сумма ÷ срок", "Сотни магазинов-партнёров"]),
    ]

    static func product(id: String) -> CreditProduct? { products.first { $0.id == id } }
    /// Cash is the «главный» product the hub hero + pre-qual anchor on.
    static var primary: CreditProduct { product(id: "cr_cash") ?? products[0] }
}

/// Formatting helpers shared across the credit module (mirrors ``SavingsFormat``'s look).
enum CreditFormat {
    static func rub(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = value < 1_000 ? 2 : 0
        f.groupingSeparator = "\u{2009}"
        let n = f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "\(n) ₽"
    }
    /// Signed ₽ for simulator deltas, e.g. «+448 000 ₽».
    static func signedRub(_ value: Double) -> String {
        (value >= 0 ? "+" : "\u{2212}") + rub(abs(value))
    }
    static func rate(_ value: Double) -> String { String(format: "%.1f%%", value) }
    static func percent(_ value: Double) -> String { String(format: "%.1f%% годовых", value) }
    static func term(_ months: Int) -> String {
        let years = months / 12, rem = months % 12
        switch (years, rem) {
        case (0, _): return "\(months) мес"
        case (_, 0): return "\(years) \(yearWord(years))"
        default:     return "\(years) \(yearWord(years)) \(rem) мес"
        }
    }
    private static func yearWord(_ n: Int) -> String {
        let n10 = n % 10, n100 = n % 100
        if n10 == 1 && n100 != 11 { return "год" }
        if (2...4).contains(n10) && !(12...14).contains(n100) { return "года" }
        return "лет"
    }
}
