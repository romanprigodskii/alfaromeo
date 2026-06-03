import Foundation

/// The two halves of the digital-asset hub (§9.6 narrative): крипта (под приходящий режим, с
/// комплаенс-гейтингом) and ЦФА (259-ФЗ — легальный «белый» путь уже сейчас). Shown as segments under
/// one unified ₽ portfolio header.
enum PortfolioSegment: String, CaseIterable, Identifiable, Hashable {
    case crypto, cfa
    var id: String { rawValue }

    var title: String {
        switch self {
        case .crypto: return "Крипта"
        case .cfa:    return "ЦФА"
        }
    }

    var caption: String {
        switch self {
        case .crypto: return "BTC · ETH · стейблы · внешние кошельки"
        case .cfa:    return "Токенизированные активы · 259-ФЗ"
        }
    }
}

/// Display denomination for the portfolio header + positions (§9.6 ₽/$ toggle, Bybit-style). Values are
/// stored in ₽ everywhere; `.usd` re-expresses them by dividing the ₽ amount by the live USD/₽ rate
/// (``LivePriceService/usdRub``). Display-only — never changes any stored balance or order.
enum PortfolioDenomination: String, CaseIterable, Identifiable, Hashable, Sendable {
    case rub, usd
    var id: String { rawValue }
    /// The currency glyph shown on the toggle.
    var symbol: String { self == .rub ? "₽" : "$" }
}

/// Where a position lives — drives its badge (watch-only) and navigation target.
enum PositionKind: Hashable, Sendable {
    case bankCrypto       // a Ромео custodial wallet
    case externalCrypto   // a linked watch-only external wallet
    case cfa              // a ЦФА holding
}

/// A single row in the unified portfolio. `qty` is in asset units (crypto) or ЦФА units; `valueRub`
/// is the live ₽ valuation.
struct CryptoPosition: Identifiable, Hashable, Sendable {
    let id: String
    let symbol: String          // BTC / USDT / AURUM …
    let title: String           // Bitcoin / Цифровое золото …
    let subtitle: String        // chain / issuer / wallet label
    let qty: Double
    let unitPriceRub: Double
    let valueRub: Double
    let change24hPct: Double?
    let kind: PositionKind
    let watchOnly: Bool
    /// Routing payload: the crypto asset symbol, or the ЦФА id.
    let routeId: String
}

/// Aggregated valuation for the header (§9.6: единый ₽-эквивалент сверху).
struct PortfolioSummary: Hashable, Sendable {
    let totalRub: Double
    let cryptoRub: Double        // bank + external, live
    let cfaRub: Double
    let externalRub: Double      // watch-only subset of cryptoRub
    let change24hRub: Double
    let change24hPct: Double

    static let zero = PortfolioSummary(totalRub: 0, cryptoRub: 0, cfaRub: 0,
                                       externalRub: 0, change24hRub: 0, change24hPct: 0)
}
