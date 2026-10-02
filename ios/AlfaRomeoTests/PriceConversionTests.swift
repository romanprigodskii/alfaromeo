import XCTest
@testable import AlfaRomeo

/// Exchange symbol mapping, the Binance snapshot filter (offline), and the ₽ conversions every screen reads.
final class PriceConversionTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    func testPairMapping() {
        XCTAssertEqual(ExchangeFeed.pair("btc"), "BTCUSDT")
        XCTAssertEqual(ExchangeFeed.pair("TON"), "GRAMUSDT")      // 2026 rebrand
        XCTAssertNil(ExchangeFeed.pair("USDT"))                    // the quote currency itself
        for asset in ["BTC", "ETH", "SOL", "TON", "USDC"] {
            XCTAssertEqual(ExchangeFeed.pair(asset).flatMap(ExchangeFeed.asset(forPair:)), asset)
        }
        XCTAssertEqual(ExchangeFeed.coinGeckoId("TON"), "the-open-network")
    }

    func testBinanceSnapshotDropsHaltedStaleAndUnknownPairs() async throws {
        let now = Date().timeIntervalSince1970 * 1000
        let stale = now - 10 * 60 * 1000
        StubURLProtocol.stub(host: "data-api.binance.vision", json: """
        [
          {"symbol": "BTCUSDT", "lastPrice": "61234.50", "priceChangePercent": "-1.250", "bidPrice": "61234.00", "closeTime": \(now)},
          {"symbol": "GRAMUSDT", "lastPrice": "5.1200", "priceChangePercent": "2.5", "bidPrice": "5.11", "closeTime": \(now)},
          {"symbol": "TONUSDT", "lastPrice": "3.0", "priceChangePercent": "0", "bidPrice": "3.0", "closeTime": \(now)},
          {"symbol": "ETHUSDT", "lastPrice": "2400.0", "priceChangePercent": "0.1", "bidPrice": "0", "closeTime": \(now)},
          {"symbol": "SOLUSDT", "lastPrice": "140.0", "priceChangePercent": "0.3", "bidPrice": "139.9", "closeTime": \(stale)}
        ]
        """)
        let feed = ExchangeFeed(session: StubURLProtocol.session())
        let snap = try await feed.snapshot(assets: ["BTC", "ETH", "SOL", "TON"], includeAggregator: false)
        XCTAssertEqual(snap.venue, .binance)
        XCTAssertEqual(snap.quotes.map(\.asset).sorted(), ["BTC", "TON"])
        let btc = snap.quotes.first { $0.asset == "BTC" }
        XCTAssertEqual(btc?.usd, 61_234.5)
        XCTAssertEqual(btc?.changePct24h, -1.25)
    }

    func testSnapshotThrowsWhenEveryVenueIsDown() async {
        let feed = ExchangeFeed(session: StubURLProtocol.session())      // nothing stubbed → 404
        do {
            _ = try await feed.snapshot(assets: ["BTC"], includeAggregator: false)
            XCTFail("expected a failure with every venue down")
        } catch {}
    }

    @MainActor
    func testPriceBookReads() {
        let prices = LivePriceService.shared
        XCTAssertEqual(prices.price("btc"), prices.price("BTC"))
        XCTAssertGreaterThan(prices.price("NO_SUCH_COIN"), 0, "unknown asset must never value at 0")
        XCTAssertEqual(prices.rubValue(asset: "ETH", qty: 2.5), 2.5 * prices.price("ETH"), accuracy: 1e-9)
        XCTAssertEqual(prices.usdRub, prices.price("USDT"))
    }

    @MainActor
    func testAccountValuationRubRate() {
        let prices = LivePriceService.shared
        let fx = FXRateService.shared
        XCTAssertEqual(AccountValuation.rubRate(currency: "RUB", prices: prices), 1)
        XCTAssertEqual(AccountValuation.rubRate(currency: "rub", prices: prices), 1)
        XCTAssertEqual(AccountValuation.rubRate(currency: "USDT", prices: prices), prices.price("USDT"))
        XCTAssertEqual(AccountValuation.rubRate(currency: "usdc", prices: prices), prices.price("USDT"))
        XCTAssertEqual(AccountValuation.rubRate(currency: "usd", prices: prices), fx.rate("USD"))
        XCTAssertTrue((20...500).contains(AccountValuation.rubRate(currency: "USD", prices: prices)))
        XCTAssertEqual(AccountValuation.rubRate(currency: "EUR", prices: prices), fx.rate("EUR"))
        let kzt = AccountValuation.rubRate(currency: "KZT", prices: prices)
        XCTAssertTrue(kzt > 0 && kzt < 1, "KZT is quoted per 100 by ЦБ, per unit it is < 1 ₽")
        XCTAssertEqual(AccountValuation.rubRate(currency: "BTC", prices: prices), prices.price("BTC"))
        XCTAssertFalse(AccountValuation.isForeignFiat("RUB"))
        XCTAssertTrue(AccountValuation.isForeignFiat("USD"))
        XCTAssertFalse(AccountValuation.isForeignFiat("USDT"))
    }
}
