import Foundation

/// One OHLC candle in ₽ — the historical counterpart of ``PriceTick`` (§11.4). Returned by
/// ``APIClient/candles(asset:range:)`` from the backend's `GET /prices/:asset/candles`. Lives in the
/// Networking layer (the price contract proper is ``PriceTick`` in Core/Contracts).
struct PriceCandle: Codable, Identifiable, Hashable, Sendable {
    let t: String   // ISO-8601 bucket start
    let o: Double   // open  (₽)
    let h: Double   // high  (₽)
    let l: Double   // low   (₽)
    let c: Double   // close (₽)

    var id: String { t }
}

/// A friendly chart range token sent to the backend (`?range=`) → CoinGecko `days` server-side.
enum CandleRange: String, CaseIterable, Sendable {
    case day = "1d"
    case week = "7d"
    case month = "30d"
    case quarter = "90d"
    case year = "365d"

    var title: String {
        switch self {
        case .day:     return "1Д"
        case .week:    return "1Н"
        case .month:   return "1М"
        case .quarter: return "3М"
        case .year:    return "1Г"
        }
    }
}
