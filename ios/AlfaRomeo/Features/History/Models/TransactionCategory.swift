import SwiftUI

/// Spending / income categories for the История module (§9.4, §10.7).
///
/// The `Transaction` contract has no `category` field yet (it ships in a later schema rev), so the
/// feed and analytics derive one locally via ``classify(_:)`` — this *is* the §10.7 «автокатегоризация»
/// stand-in: a keyword + `kind` heuristic over the merchant string. Each case carries an SF Symbol and
/// a stable, dark-scheme-friendly tint used both for the row chips and the Swift Charts slices.
enum TransactionCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    // expense-leaning
    case groceries
    case marketplace
    case subscriptions
    case dining
    case transport
    case mobile
    case entertainment
    // both
    case transfers
    case crypto
    // income-leaning
    case salary
    case cashback
    case acquiring
    case deposit
    // fallback
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groceries:     return "Продукты"
        case .marketplace:   return "Маркетплейсы"
        case .subscriptions: return "Подписки"
        case .dining:        return "Кафе и рестораны"
        case .transport:     return "Транспорт"
        case .mobile:        return "Связь"
        case .entertainment: return "Развлечения"
        case .transfers:     return "Переводы"
        case .crypto:        return "Крипта"
        case .salary:        return "Зарплата"
        case .cashback:      return "Кэшбек"
        case .acquiring:     return "Эквайринг"
        case .deposit:       return "Вклады"
        case .other:         return "Прочее"
        }
    }

    var icon: String {
        switch self {
        case .groceries:     return "cart.fill"
        case .marketplace:   return "bag.fill"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .dining:        return "fork.knife"
        case .transport:     return "car.fill"
        case .mobile:        return "antenna.radiowaves.left.and.right"
        case .entertainment: return "gamecontroller.fill"
        case .transfers:     return "arrow.left.arrow.right"
        case .crypto:        return "bitcoinsign.circle.fill"
        case .salary:        return "briefcase.fill"
        case .cashback:      return "gift.fill"
        case .acquiring:     return "qrcode"
        case .deposit:       return "banknote.fill"
        case .other:         return "ellipsis.circle.fill"
        }
    }

    /// Categorical palette — vivid, well-separated hues that read on the primary dark scheme (§13.1).
    /// Kept inside the module so it can pick colors freely without widening the global token set. The
    /// hue is stored as a packed hex so ``CategoryRef`` can carry built-in and custom tints uniformly.
    var tintHex: UInt32 {
        switch self {
        case .groceries:     return 0x34C759
        case .marketplace:   return 0xFF9F0A
        case .subscriptions: return 0x5E7CFF
        case .dining:        return 0xFF6482
        case .transport:     return 0x32ADE6
        case .mobile:        return 0x30D5C8
        case .entertainment: return 0xBF5AF2
        case .transfers:     return 0x9AA2B1
        case .crypto:        return 0x64D2FF
        case .salary:        return 0x30D158
        case .cashback:      return 0xFFD426
        case .acquiring:     return 0x0A84FF
        case .deposit:       return 0xC8A26A
        case .other:         return 0x98989D
        }
    }

    var tint: Color { Color(hex: tintHex) }

    // MARK: - Auto-categorization (§10.7)

    /// Best-effort category for a transaction from its `kind` + merchant string. Deterministic so the
    /// feed, the donut, and the detail screen all agree on the same color/icon for a given operation.
    static func classify(_ tx: Transaction) -> TransactionCategory {
        let name = (tx.counterparty ?? "").lowercased()

        switch tx.kind {
        case .convert, .trade:
            return .crypto
        case .acquire:
            return .acquiring
        case .payout:
            if name.contains("зарплат") || name.contains("salary") { return .salary }
            return tx.amount >= 0 ? .salary : .transfers
        case .transfer:
            return .transfers
        case .payment:
            if matches(name, ["пятёроч", "пятероч", "перекрёст", "перекрест", "магнит", "вкусвилл",
                              "лента", "ашан", "самокат", "azbuka", "продукт"]) { return .groceries }
            if matches(name, ["wildberries", "ozon", "озон", "мегамаркет", "aliexpress",
                              "яндекс маркет", "yandex market", "детский мир", "lamoda"]) { return .marketplace }
            if matches(name, ["плюс", "steam", "apple", "spotify", "netflix", "подписк",
                              "ivi", "кинопоиск", "youtube", "ютуб", "premium", "subscription"]) { return .subscriptions }
            if matches(name, ["кафе", "ресторан", "кофе", "coffee", "бар", "starbucks",
                              "шоколадниц", "додо", "kfc", "мак", "burger", "вкусно"]) { return .dining }
            if matches(name, ["такси", "uber", "yandex go", "яндекс go", "метро", "ржд",
                              "аэрофлот", "заправ", "азс", "транспорт", "парков"]) { return .transport }
            if matches(name, ["мтс", "билайн", "мегафон", "tele2", "ромео mobile",
                              "связь", "мобайл", "mobile"]) { return .mobile }
            if matches(name, ["кино", "театр", "игр", "game", "концерт", "afisha", "афиша"]) { return .entertainment }
            return .other
        }
    }

    private static func matches(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }
}
