import Foundation

/// Поступление в отчёте по выручке (§8.2). `grossRub` — зачислено в ₽ (для крипты — уже после
/// авто-конвертации); крипто-строки несут объём стейбла, который сконвертировался.
struct RevenueEntry: Identifiable, Hashable, Sendable {
    let id: String
    let method: PaymentMethod
    let grossRub: Double
    let counterparty: String
    let createdAt: Date
    let cryptoAsset: String?
    let cryptoAmount: Double?

    var wasCrypto: Bool { method.isCrypto }
}

/// Фильтр отчёта по выручке (по способу приёма).
enum RevenueFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all, card, sbp, digitalRuble, crypto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:          return "Все"
        case .card:         return "Карты"
        case .sbp:          return "СБП"
        case .digitalRuble: return "Цифр. ₽"
        case .crypto:       return "Крипта"
        }
    }

    /// nil → без фильтра по методу.
    var method: PaymentMethod? {
        switch self {
        case .all:          return nil
        case .card:         return .card
        case .sbp:          return .sbp
        case .digitalRuble: return .digitalRuble
        case .crypto:       return .crypto
        }
    }

    func matches(_ entry: RevenueEntry) -> Bool {
        guard let m = method else { return true }
        return entry.method == m
    }
}

/// Сводка по выручке — для хедера хаба и отчёта.
struct RevenueSummary: Hashable, Sendable {
    /// Доля одного способа приёма в общей выручке.
    struct MethodSlice: Identifiable, Hashable, Sendable {
        let method: PaymentMethod
        let amount: Double
        var id: String { method.rawValue }
    }

    let total: Double
    let count: Int
    /// Сколько ₽ пришло через крипто-приём (после авто-конвертации).
    let cryptoConvertedRub: Double
    let byMethod: [MethodSlice]

    /// Доля метода в общей выручке (0...1) — для мини-разбивки.
    func share(_ slice: MethodSlice) -> Double {
        total > 0 ? slice.amount / total : 0
    }

    static let empty = RevenueSummary(total: 0, count: 0, cryptoConvertedRub: 0, byMethod: [])
}
