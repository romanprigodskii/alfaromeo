import Foundation
import Observation

/// Where a chart timeframe's candles came from — captioned under the chart so it never passes a
/// synthetic series off as market data.
enum CandleSource: Hashable, Sendable {
    case exchange(ExchangeVenue)
    case backend
    case synthetic

    var caption: String {
        switch self {
        case .exchange(let venue): return venue.title
        case .backend:             return "сервер"
        case .synthetic:           return "синтетика"
        }
    }
}

/// Drives the crypto asset detail (§9.6): loads real OHLC candles per chart ``Timeframe`` and exposes
/// the live price (read from ``LivePriceService``).
///
/// Candle chain per timeframe: **exchange klines** (Binance → Bybit; exact 15м/1Ч/4Ч/1Д intervals,
/// USD × the live USD/₽ rate) → our backend's `/prices/:asset/candles` (1Д only, when the backend is the
/// live price source) → nothing, and the view falls back to ``SyntheticMarket`` captioned «синтетика».
/// Results are cached per timeframe for a minute, failures included, so tab switches don't re-hit a
/// dead venue.
@MainActor
@Observable
final class AssetDetailModel {
    let symbol: String
    private(set) var candles: [Timeframe: [PriceCandle]] = [:]
    private(set) var sources: [Timeframe: CandleSource] = [:]
    private(set) var loading: Set<Timeframe> = []

    private let exchange = ExchangeFeed()
    private let live = LiveAPIClient()
    @ObservationIgnored private var fetchedAt: [Timeframe: Date] = [:]

    init(symbol: String) { self.symbol = symbol }

    var asset: CryptoAsset? { CryptoCatalog.asset(symbol) }
    var stakingApy: Double? { MockCryptoData.stakingApy(for: symbol) }

    func candleSource(_ timeframe: Timeframe) -> CandleSource { sources[timeframe] ?? .synthetic }

    func loadChart(_ timeframe: Timeframe) async {
        if let at = fetchedAt[timeframe], Date().timeIntervalSince(at) < 60 { return }
        guard !loading.contains(timeframe) else { return }
        loading.insert(timeframe)
        defer { loading.remove(timeframe) }

        let prices = LivePriceService.shared
        if let result = try? await exchange.klines(asset: symbol, interval: timeframe.klineInterval,
                                                   limit: timeframe.candleCount),
           !result.candles.isEmpty {
            // History is converted at today's rate — the same simplification the backend makes.
            let usdRub = prices.usdRub
            candles[timeframe] = result.candles.map { $0.scaled(by: usdRub) }
            sources[timeframe] = .exchange(result.venue)
        } else if timeframe == .d1, prices.source == .backend,
                  let server = try? await live.candles(asset: symbol, range: .month), !server.isEmpty {
            candles[timeframe] = Array(server.suffix(timeframe.candleCount))
            sources[timeframe] = .backend
        } else {
            candles[timeframe] = nil
            sources[timeframe] = .synthetic
        }
        fetchedAt[timeframe] = Date()
    }
}
