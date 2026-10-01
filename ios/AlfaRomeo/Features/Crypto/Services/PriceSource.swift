import Foundation

/// Where the crypto prices on screen come from (§11.4) — the active leg of ``LivePriceService``'s
/// fallback chain, so the UI says it honestly («LIVE · Binance», «Демо-цены») instead of claiming
/// «live» unconditionally.
enum PriceSource: Hashable, Sendable {
    /// Our backend (`/prices` + `/ws/prices`), ₽ priced server-side.
    case backend
    /// A public exchange directly — USD quotes × курс ЦБ.
    case exchange(ExchangeVenue)
    /// Local demo walk — no network source answered.
    case demo

    /// A real market feed (backend or exchange) — what the legacy `isLive` flag means.
    var isLive: Bool { self != .demo }

    /// Short badge text.
    var badgeTitle: String {
        switch self {
        case .backend:            return "LIVE · сервер"
        case .exchange(let venue): return "LIVE · \(venue.title)"
        case .demo:               return "Демо-цены"
        }
    }

    /// Badge text when the live leg has gone quiet (no fresh price for a while).
    var staleTitle: String {
        switch self {
        case .backend:            return "Сервер · задержка"
        case .exchange(let venue): return "\(venue.title) · задержка"
        case .demo:               return badgeTitle
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .backend:            return "Живые цены с сервера банка"
        case .exchange(let venue): return "Живые цены с биржи \(venue.title)"
        case .demo:               return "Демонстрационные цены, нет связи с биржей"
        }
    }

    /// One-line provenance for an «Источник» info row.
    var detail: String {
        switch self {
        case .backend:            return "Сервер банка"
        case .exchange(let venue): return "\(venue.title) · USDT × курс ЦБ"
        case .demo:               return "Демо: нет связи с биржей"
        }
    }
}
