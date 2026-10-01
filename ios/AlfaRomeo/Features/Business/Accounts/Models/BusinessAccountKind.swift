import Foundation

/// Presentation grouping for the business РКО list (§8.2): rouble settlement accounts, multicurrency
/// (foreign-fiat) accounts, and the crypto treasury (stablecoins as operating currency). The contract
/// ``Account`` carries only `type` + `currency`; this is the *display* classification derived from them
/// — no contract change, no data duplication.
enum BusinessAccountGroup: String, CaseIterable, Identifiable, Hashable {
    case rubles        // ₽ расчётные / накопительные
    case multicurrency // валютные (USD, …)
    case treasury      // крипто-трежери (USDT / USDC, …)

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rubles:        return "Рублёвые счета"
        case .multicurrency: return "Валютные счета"
        case .treasury:      return "Крипто-трежери"
        }
    }

    var caption: String {
        switch self {
        case .rubles:        return "РКО: расчётный и накопительный"
        case .multicurrency: return "Оценка в ₽ по курсу ЦБ"
        case .treasury:      return "Стейблкоины, оценка в ₽ по live-курсу"
        }
    }
}

/// One РКО account joined with its live ₽ valuation — the row view-model the Счета list and the balance
/// hero consume. Wraps the contract ``Account`` (source of truth for balance / currency / type); the ₽
/// value is computed by ``BusinessAccountsStore`` from ``LivePriceService`` (stables/USD are $-pegged).
struct BusinessAccountItem: Identifiable, Hashable {
    let account: Account
    /// ₽ equivalent of the native balance at the live rate (RUB == balance).
    let rubValue: Double

    var id: String { account.id }
    var currency: String { account.currency }
    var balance: Double { account.balance }

    var group: BusinessAccountGroup {
        if account.type == .crypto { return .treasury }
        if account.currency.uppercased() != "RUB" { return .multicurrency }
        return .rubles
    }

    /// True when the native currency isn't ₽ — the row then shows a «≈ … ₽» sub-line.
    var showsRubEquivalent: Bool { account.currency.uppercased() != "RUB" }

    var title: String {
        switch group {
        case .rubles:
            switch account.type {
            case .savings:      return "Накопительный счёт"
            case .digitalRuble: return "Цифровой рубль"
            default:            return "Расчётный счёт"
            }
        case .multicurrency: return "Валютный счёт · \(currency)"
        case .treasury:      return "Трежери · \(currency)"
        }
    }

    var subtitle: String {
        switch group {
        case .rubles:        return "Основной счёт · РКО"
        case .multicurrency: return "Мультивалютный · оценка по курсу ЦБ"
        case .treasury:      return "Стейбл · операционная валюта"
        }
    }

    var icon: String {
        switch group {
        case .rubles:        return "building.columns.fill"
        case .multicurrency: return "dollarsign.circle.fill"
        case .treasury:      return "bitcoinsign.circle.fill"
        }
    }

    /// A stable masked account suffix derived deterministically from the id (the contract has no IBAN),
    /// so the list reads like real РКО («·· 3900») without inventing a stored field.
    var maskedNumber: String {
        let n = account.id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return "·· \(1000 + (n * 37) % 9000)"
    }
}
