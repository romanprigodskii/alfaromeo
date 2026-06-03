import Foundation
import Observation

/// Drives the crypto asset detail (§9.6): loads historical OHLC candles per timeframe for the Swift
/// Charts view, toggles line/candles, and exposes the live price (read from ``LivePriceService``).
/// Candles prefer the **live** backend (`/prices/:asset/candles`) and fall back to the injected client
/// (mock) so the chart always renders.
@MainActor
@Observable
final class AssetDetailModel {
    let symbol: String
    var range: CandleRange = .week
    private(set) var candles: [PriceCandle] = []
    private(set) var isLoading = false

    private let live = LiveAPIClient()

    init(symbol: String) { self.symbol = symbol }

    var asset: CryptoAsset? { CryptoCatalog.asset(symbol) }
    var stakingApy: Double? { MockCryptoData.stakingApy(for: symbol) }

    func load(api: any APIClient) async {
        await fetch(api: api)
    }

    func select(range: CandleRange, api: any APIClient) async {
        guard range != self.range else { return }
        self.range = range
        await fetch(api: api)
    }

    private func fetch(api: any APIClient) async {
        isLoading = true
        defer { isLoading = false }
        if let live = try? await live.candles(asset: symbol, range: range), !live.isEmpty {
            candles = live
        } else if let mock = try? await api.candles(asset: symbol, range: range), !mock.isEmpty {
            candles = mock
        } else {
            candles = MockData.candles(symbol, range: range)
        }
    }
}
