import Foundation

/// Which public venue served a direct-exchange price — shown in the source badge («LIVE · Binance»).
enum ExchangeVenue: String, Sendable, Hashable {
    case binance, bybit, coinGecko

    var title: String {
        switch self {
        case .binance:   return "Binance"
        case .bybit:     return "Bybit"
        case .coinGecko: return "CoinGecko"
        }
    }
}

/// One USD(T) quote from a public venue. Deliberately kept in **dollars**: the single ₽ conversion
/// (× USD/₽ курс ЦБ from ``FxRateClient``) lives in ``LivePriceService`` so every screen agrees on
/// one rate.
struct ExchangeQuote: Sendable, Hashable {
    let asset: String            // app symbol: BTC, ETH, TON, …
    let usd: Double
    let changePct24h: Double?    // already in % (venue's rolling 24h)
    let ts: Date
}

/// Direct public-exchange market data (§11.4) — the fallback leg ``LivePriceService`` uses when our
/// backend is unreachable, so the demo shows **real** prices instead of a random walk.
///
/// - Snapshot: Binance market-data mirror (`data-api.binance.vision`, keyless) → Bybit → CoinGecko.
/// - Stream: Binance combined `@miniTicker` WebSocket (`data-stream.binance.vision`), auto-reconnect
///   with the same exponential backoff as ``PriceSocket``.
/// - Klines: Binance → Bybit, USD OHLC + base volume for the trading chart.
///
/// No RUB pairs are used on purpose: every exchange `…RUB` pair is halted (frozen ~9% off), so ₽ is
/// always USDT × курс ЦБ. Stateless value type — safe to hand to child tasks.
struct ExchangeFeed: Sendable {
    let session: URLSession

    init(session: URLSession = ExchangeFeed.restSession) {
        self.session = session
    }

    /// Short-timeout REST session: a dead venue must fail fast so the chain can move on.
    static let restSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 10
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    // MARK: Symbols

    /// App symbol → USDT spot pair. TON trades as **GRAM** since the 2026 rebrand (`TONUSDT` is halted
    /// on Binance with a frozen price); USDT is the quote currency itself, so it has no pair.
    static func pair(_ asset: String) -> String? {
        switch asset.uppercased() {
        case "BTC":  return "BTCUSDT"
        case "ETH":  return "ETHUSDT"
        case "SOL":  return "SOLUSDT"
        case "TON":  return "GRAMUSDT"
        case "USDC": return "USDCUSDT"
        default:     return nil
        }
    }

    static func asset(forPair pair: String) -> String? {
        switch pair.uppercased() {
        case "BTCUSDT":  return "BTC"
        case "ETHUSDT":  return "ETH"
        case "SOLUSDT":  return "SOL"
        case "GRAMUSDT": return "TON"
        case "USDCUSDT": return "USDC"
        default:         return nil
        }
    }

    static func coinGeckoId(_ asset: String) -> String? {
        switch asset.uppercased() {
        case "BTC":  return "bitcoin"
        case "ETH":  return "ethereum"
        case "USDT": return "tether"
        case "SOL":  return "solana"
        case "TON":  return "the-open-network"
        case "USDC": return "usd-coin"
        default:     return nil
        }
    }

    // MARK: Snapshot

    /// The freshest USD snapshot from the first venue that answers. CoinGecko (rate-limited to a few
    /// calls a minute) is tried only when `includeAggregator` — the caller throttles it.
    func snapshot(assets: [String], includeAggregator: Bool = true) async throws -> (venue: ExchangeVenue, quotes: [ExchangeQuote]) {
        if let quotes = try? await binanceSnapshot(assets), !quotes.isEmpty { return (.binance, quotes) }
        if let quotes = try? await bybitSnapshot(assets), !quotes.isEmpty { return (.bybit, quotes) }
        guard includeAggregator else { throw APIError.transport("exchanges unreachable") }
        let quotes = try await coinGeckoSnapshot(assets)
        guard !quotes.isEmpty else { throw APIError.invalidResponse }
        return (.coinGecko, quotes)
    }

    /// `GET /api/v3/ticker/24hr?symbols=[…]` — strings for every number. A halted pair (bid 0) or a
    /// window that closed > 5 min ago is dropped, so a frozen price never passes as live.
    private func binanceSnapshot(_ assets: [String]) async throws -> [ExchangeQuote] {
        struct Row: Decodable {
            let symbol: String
            let lastPrice: String
            let priceChangePercent: String
            let bidPrice: String
            let closeTime: Double
        }
        let list = assets.compactMap(Self.pair).map { "%22\($0)%22" }.joined(separator: "%2C")
        guard var components = URLComponents(string: "https://data-api.binance.vision/api/v3/ticker/24hr") else {
            throw APIError.invalidResponse
        }
        components.percentEncodedQuery = "symbols=%5B\(list)%5D"
        guard let url = components.url else { throw APIError.invalidResponse }

        let rows: [Row] = try await getJSON(url)
        let now = Date()
        return rows.compactMap { row in
            guard let asset = Self.asset(forPair: row.symbol),
                  let usd = Double(row.lastPrice), usd > 0,
                  (Double(row.bidPrice) ?? 0) > 0 else { return nil }
            let ts = Date(timeIntervalSince1970: row.closeTime / 1000)
            guard now.timeIntervalSince(ts) < 300 else { return nil }
            return ExchangeQuote(asset: asset, usd: usd, changePct24h: Double(row.priceChangePercent), ts: ts)
        }
    }

    /// `GET /v5/market/tickers?category=spot&symbol=…` per pair (tiny payloads, fetched concurrently).
    /// `price24hPcnt` is a fraction → ×100.
    private func bybitSnapshot(_ assets: [String]) async throws -> [ExchangeQuote] {
        struct Envelope: Decodable {
            struct Result: Decodable { let list: [Row] }
            struct Row: Decodable {
                let symbol: String
                let lastPrice: String
                let price24hPcnt: String?
                let bid1Price: String?
            }
            let retCode: Int
            let result: Result
            let time: Double
        }
        let pairs = assets.compactMap(Self.pair)
        return await withTaskGroup(of: ExchangeQuote?.self) { group in
            for pair in pairs {
                group.addTask {
                    guard let url = URL(string: "https://api.bybit.com/v5/market/tickers?category=spot&symbol=\(pair)"),
                          let env: Envelope = try? await getJSON(url), env.retCode == 0,
                          let row = env.result.list.first,
                          let asset = Self.asset(forPair: row.symbol),
                          let usd = Double(row.lastPrice), usd > 0,
                          (Double(row.bid1Price ?? "") ?? 0) > 0 else { return nil }
                    let change = row.price24hPcnt.flatMap(Double.init).map { $0 * 100 }
                    return ExchangeQuote(asset: asset, usd: usd, changePct24h: change,
                                         ts: Date(timeIntervalSince1970: env.time / 1000))
                }
            }
            var out: [ExchangeQuote] = []
            for await quote in group { if let quote { out.append(quote) } }
            return out
        }
    }

    /// CoinGecko `simple/price` — the last-resort aggregator (keyless, but 429s after a few quick calls).
    private func coinGeckoSnapshot(_ assets: [String]) async throws -> [ExchangeQuote] {
        struct Row: Decodable {
            let usd: Double?
            let usd_24h_change: Double?
            let last_updated_at: Double?
        }
        let ids = assets.compactMap(Self.coinGeckoId)
        let query = "ids=\(ids.joined(separator: ","))&vs_currencies=usd&include_24hr_change=true&include_last_updated_at=true"
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?\(query)") else {
            throw APIError.invalidResponse
        }
        let rows: [String: Row] = try await getJSON(url)
        return assets.compactMap { asset in
            guard let id = Self.coinGeckoId(asset), let row = rows[id], let usd = row.usd, usd > 0 else { return nil }
            let ts = row.last_updated_at.map { Date(timeIntervalSince1970: $0) } ?? Date()
            return ExchangeQuote(asset: asset.uppercased(), usd: usd, changePct24h: row.usd_24h_change, ts: ts)
        }
    }

    // MARK: Stream

    /// Binance combined `@miniTicker` stream → USD quotes (~1 push/s per symbol that moved; 24h % is
    /// derived from the rolling open). Reconnects with exponential backoff (2s → 15s cap) and only
    /// finishes when the consumer cancels. The server pings every ~20s; URLSession answers pings itself.
    func stream(assets: [String]) -> AsyncStream<ExchangeQuote> {
        let streams = assets.compactMap(Self.pair).map { "\($0.lowercased())@miniTicker" }.joined(separator: "/")
        guard let url = URL(string: "wss://data-stream.binance.vision/stream?streams=\(streams)") else {
            return AsyncStream { $0.finish() }
        }
        return AsyncStream { continuation in
            let task = Task {
                var attempt = 0
                while !Task.isCancelled {
                    let ws = URLSession.shared.webSocketTask(with: url)
                    ws.resume()
                    let received = await withTaskCancellationHandler {
                        var any = false
                        do {
                            while !Task.isCancelled {
                                let message = try await ws.receive()
                                if let quote = Self.decodeMiniTicker(message) {
                                    any = true
                                    continuation.yield(quote)
                                }
                            }
                        } catch {
                            // Dropped / refused — fall through to backoff + reconnect.
                        }
                        return any
                    } onCancel: {
                        ws.cancel(with: .goingAway, reason: nil)
                    }
                    ws.cancel(with: .goingAway, reason: nil)
                    if Task.isCancelled { break }

                    attempt = received ? 1 : attempt + 1
                    let delayMs = min(1000 * (1 << min(attempt, 4)), 15_000)   // 2s,4s,…,15s cap
                    try? await Task.sleep(for: .milliseconds(delayMs))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// `{"stream":"btcusdt@miniTicker","data":{"s":"BTCUSDT","c":"84798.96","o":"83629.99","E":…}}`
    private static func decodeMiniTicker(_ message: URLSessionWebSocketTask.Message) -> ExchangeQuote? {
        struct Frame: Decodable {
            struct Payload: Decodable {
                let s: String
                let c: String
                let o: String
                let E: Double
            }
            let data: Payload
        }
        let data: Data
        switch message {
        case .string(let text): data = Data(text.utf8)
        case .data(let d):      data = d
        @unknown default:       return nil
        }
        guard let frame = try? JSONDecoder().decode(Frame.self, from: data),
              let asset = asset(forPair: frame.data.s),
              let close = Double(frame.data.c), close > 0 else { return nil }
        let open = Double(frame.data.o) ?? 0
        let change = open > 0 ? (close - open) / open * 100 : nil
        return ExchangeQuote(asset: asset, usd: close, changePct24h: change,
                             ts: Date(timeIntervalSince1970: frame.data.E / 1000))
    }

    // MARK: Klines

    /// Historical **USD** OHLC + base volume, oldest first — Binance klines, Bybit as the reserve.
    /// `interval` uses Binance tokens (`15m`, `1h`, `4h`, `1d`); the caller converts to ₽.
    func klines(asset: String, interval: String, limit: Int) async throws -> (venue: ExchangeVenue, candles: [PriceCandle]) {
        guard let pair = Self.pair(asset) else { throw APIError.invalidResponse }
        if let candles = try? await binanceKlines(pair: pair, interval: interval, limit: limit), !candles.isEmpty {
            return (.binance, candles)
        }
        let candles = try await bybitKlines(pair: pair, interval: interval, limit: limit)
        guard !candles.isEmpty else { throw APIError.invalidResponse }
        return (.bybit, candles)
    }

    /// Rows: `[openMs, "o", "h", "l", "c", "v", closeMs, …]`, oldest first.
    private func binanceKlines(pair: String, interval: String, limit: Int) async throws -> [PriceCandle] {
        guard let url = URL(string: "https://data-api.binance.vision/api/v3/klines?symbol=\(pair)&interval=\(interval)&limit=\(limit)") else {
            throw APIError.invalidResponse
        }
        let data = try await getData(url)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[Any]] else { throw APIError.invalidResponse }
        return rows.compactMap { Self.candle(ms: $0.first, fields: Array($0.dropFirst().prefix(5))) }
    }

    /// Rows: `["startMs", "o", "h", "l", "c", "vol", "turnover"]`, **newest first** → reversed.
    private func bybitKlines(pair: String, interval: String, limit: Int) async throws -> [PriceCandle] {
        let bybitInterval: String
        switch interval {
        case "15m": bybitInterval = "15"
        case "1h":  bybitInterval = "60"
        case "4h":  bybitInterval = "240"
        default:    bybitInterval = "D"
        }
        guard let url = URL(string: "https://api.bybit.com/v5/market/kline?category=spot&symbol=\(pair)&interval=\(bybitInterval)&limit=\(limit)") else {
            throw APIError.invalidResponse
        }
        let data = try await getData(url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any],
              let rows = result["list"] as? [[Any]] else { throw APIError.invalidResponse }
        return rows.reversed().compactMap { Self.candle(ms: $0.first, fields: Array($0.dropFirst().prefix(5))) }
    }

    /// Builds a USD candle from a kline row's open-time (ms, number or string) and its
    /// `[o, h, l, c, v]` string fields.
    private static func candle(ms raw: Any?, fields: [Any]) -> PriceCandle? {
        let ms: Double?
        switch raw {
        case let n as NSNumber: ms = n.doubleValue
        case let s as String:   ms = Double(s)
        default:                ms = nil
        }
        let values = fields.compactMap { ($0 as? String).flatMap(Double.init) }
        guard let ms, values.count == 5 else { return nil }
        let t = isoFormatter.string(from: Date(timeIntervalSince1970: ms / 1000))
        return PriceCandle(t: t, o: values[0], h: values[1], l: values[2], c: values[3], v: values[4])
    }

    private static let isoFormatter = ISO8601DateFormatter()

    // MARK: HTTP

    private func getData(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(status: http.statusCode) }
        return data
    }

    private func getJSON<T: Decodable>(_ url: URL) async throws -> T {
        let data = try await getData(url)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}
