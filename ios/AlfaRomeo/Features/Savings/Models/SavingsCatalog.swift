import Foundation

// «Приумножить» — рублёвые вклады + крипто-стейкинг в одном хабе (§10.6). The catalog below is the
// demo product shelf; per-product APY is later boosted by the active tier (§4) in ``SavingsRates``.

// MARK: - Risk framing (honest disclosure, §10.6)

/// АСВ-insured deposit vs un-insured market-risk stake — the honest contrast the hub makes explicit.
enum SavingsRisk: Sendable {
    case insuredASV     // вклад застрахован Агентством по страхованию вкладов
    case marketRisk     // стейкинг — рыночный риск, НЕ застрахован

    var badge: String {
        switch self {
        case .insuredASV: return "Застраховано АСВ"
        case .marketRisk: return "Не застраховано"
        }
    }
    var headline: String {
        switch self {
        case .insuredASV: return "Застраховано АСВ до 1,4 млн ₽"
        case .marketRisk: return "Рыночный риск · не застраховано"
        }
    }
    var detail: String {
        switch self {
        case .insuredASV:
            return "Возврат гарантирован государством через Агентство по страхованию вкладов в пределах 1,4 млн ₽. Доходность фиксированная."
        case .marketRisk:
            return "Доходность и тело зависят от цены актива и сети. Это не вклад: средства не застрахованы АСВ, возможна потеря части стоимости."
        }
    }
    var systemImage: String {
        switch self {
        case .insuredASV: return "checkmark.shield.fill"
        case .marketRisk: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Ruble deposit products

/// A ruble-deposit template (ставка / срок / капитализация / пополнение, §10.6).
struct DepositProduct: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let tagline: String
    let baseApy: Double            // annual %, before the tier premium (§4)
    let termsMonths: [Int]         // selectable terms
    let allowsCapitalization: Bool
    let allowsTopUp: Bool
    let allowsWithdrawal: Bool
    let minAmount: Double

    var risk: SavingsRisk { .insuredASV }
    var defaultTerm: Int { termsMonths.first ?? 6 }
}

// MARK: - Crypto staking products

/// Volatility/risk band for a staking asset — colored honestly in the UI.
enum StakeRiskLevel: String, Sendable, CaseIterable {
    case low, medium, high
    var label: String {
        switch self {
        case .low:    return "Низкий риск"
        case .medium: return "Средний риск"
        case .high:   return "Высокий риск"
        }
    }
}

/// A crypto-staking template (актив / APY / lock / риск, §10.6). `principal` of the resulting
/// ``Deposit`` is denominated in asset units; its ₽ value is read live from ``SavingsStore``.
struct StakeProduct: Identifiable, Hashable, Sendable {
    let id: String
    let asset: String              // BTC / ETH / USDT / SOL / TON (BTC/ETH + стейблы, §2.4)
    let name: String
    let baseApy: Double            // annual %, before the tier premium (§4)
    let lockOptionsDays: [Int]     // 0 = гибкий (без lock)
    let riskLevel: StakeRiskLevel
    let minUnits: Double

    var risk: SavingsRisk { .marketRisk }
    var defaultLock: Int { lockOptionsDays.first ?? 0 }
}

// MARK: - Catalog

enum SavingsCatalog {
    static let depositProducts: [DepositProduct] = [
        DepositProduct(
            id: "dep_easy", name: "Лёгкий старт", tagline: "Снимай и пополняй когда угодно",
            baseApy: 12.0, termsMonths: [3, 6, 12],
            allowsCapitalization: true, allowsTopUp: true, allowsWithdrawal: true, minAmount: 1_000),
        DepositProduct(
            id: "dep_term", name: "Срочный 2035", tagline: "Выше ставка за фиксированный срок",
            baseApy: 16.5, termsMonths: [6, 12, 24],
            allowsCapitalization: true, allowsTopUp: false, allowsWithdrawal: false, minAmount: 30_000),
        DepositProduct(
            id: "dep_max", name: "Максимум", tagline: "Премиальная ставка для крупной суммы",
            baseApy: 18.0, termsMonths: [12, 18],
            allowsCapitalization: true, allowsTopUp: false, allowsWithdrawal: false, minAmount: 100_000),
    ]

    // Only BTC/ETH + stablecoins are admitted under the приходящий режим (§2.4); SOL/TON are tradable
    // in the Crypto Hub but intentionally NOT offered for staking on the licensed platform.
    static let stakeProducts: [StakeProduct] = [
        StakeProduct(id: "stk_usdt", asset: "USDT", name: "USDT · стейблкоин",
                     baseApy: 9.5, lockOptionsDays: [0, 30, 90], riskLevel: .low, minUnits: 100),
        StakeProduct(id: "stk_eth", asset: "ETH", name: "Ethereum",
                     baseApy: 4.2, lockOptionsDays: [0, 30, 90], riskLevel: .medium, minUnits: 0.01),
        StakeProduct(id: "stk_btc", asset: "BTC", name: "Bitcoin",
                     baseApy: 3.0, lockOptionsDays: [30, 90, 180], riskLevel: .medium, minUnits: 0.001),
    ]

    static func depositProduct(id: String) -> DepositProduct? { depositProducts.first { $0.id == id } }
    static func stakeProduct(id: String) -> StakeProduct? { stakeProducts.first { $0.id == id } }
    /// Resolve a stake product by crypto symbol (the Crypto-hub entry point passes a symbol, §9.6).
    static func stakeProduct(asset: String) -> StakeProduct? {
        stakeProducts.first { $0.asset.caseInsensitiveCompare(asset) == .orderedSame }
    }
}

// MARK: - Formatting helpers (shared across the module)

enum SavingsFormat {
    /// ₽ amount with thin-space grouping (matches ``AmountText``'s monetary look for inline strings).
    static func rub(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = value < 1_000 ? 2 : 0
        f.groupingSeparator = "\u{2009}"
        let n = f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "\(n) ₽"
    }

    /// Asset-unit amount with sensible precision (e.g. `0.015300 ETH`, `1 820 USDT`).
    static func units(_ value: Double, asset: String) -> String {
        let digits = value == 0 ? 0 : (value < 1 ? 6 : (value < 100 ? 4 : 2))
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits
        f.groupingSeparator = "\u{2009}"
        let n = f.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(n) \(asset)"
    }

    static func percent(_ value: Double) -> String { String(format: "%.1f%%", value) }
}
