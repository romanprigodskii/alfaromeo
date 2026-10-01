import Foundation

/// ₽ crypto price ticks over `URLSessionWebSocketTask` (§11.4, §11.9).
///
/// - `.live` connects to **our** backend `/ws/prices`: subscribes to the asset set, parses ₽
///   ``PriceTick`` frames, and reconnects with exponential backoff.
/// - `.mock` runs a local demo walk (offline fallback): small mean-reverting moves around a seed,
///   stablecoins flat, and no fake per-tick «24h %» (the snapshot's 24h change is kept).
///
/// Direct public-exchange data (USD quotes, converted to ₽ in ``LivePriceService``) lives in
/// ``ExchangeFeed`` — the old CoinCap socket (`ws.coincap.io`) is shut down and was removed.
///
/// Confined to `@MainActor` (its callers already are), so the mutable task/socket state needs no
/// extra synchronization and the type is `Sendable` without `@unchecked`.
@MainActor
final class PriceSocket {
    enum Source: Sendable { case mock, live }

    let source: Source
    let assets: [String]
    let environment: APIEnvironment
    /// Optional starting ₽ prices for the `.mock` walk (e.g. the last real prices), keyed UPPERCASE.
    let seeds: [String: Double]

    private var generator: Task<Void, Never>?
    private var liveTask: Task<Void, Never>?
    private var wsTask: URLSessionWebSocketTask?

    init(source: Source = .mock, assets: [String], seeds: [String: Double] = [:],
         environment: APIEnvironment = .current) {
        self.source = source
        self.assets = assets
        self.seeds = seeds
        self.environment = environment
    }

    /// A stream of ticks. For `.mock`, ticks arrive ~every 0.8s; `.live` streams real backend ticks
    /// (with auto-reconnect).
    func ticks() -> AsyncStream<PriceTick> {
        AsyncStream { continuation in
            switch source {
            case .mock:
                let assets = self.assets
                let seeds = self.seeds
                let task = Task { await Self.runMock(assets: assets, seeds: seeds, into: continuation) }
                generator = task
                continuation.onTermination = { [weak self] _ in
                    task.cancel()
                    Task { @MainActor in self?.generator = nil }
                }
            case .live:
                let task = Task { [weak self] in
                    guard let self else { return }
                    await self.runLive(into: continuation)
                }
                liveTask = task
                continuation.onTermination = { [weak self] _ in
                    task.cancel()
                    Task { @MainActor in self?.stop() }
                }
            }
        }
    }

    func stop() {
        generator?.cancel()
        generator = nil
        liveTask?.cancel()
        liveTask = nil
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
    }

    // MARK: Live (our backend /ws/prices)

    /// Connect → subscribe → stream ₽ ticks; reconnect with exponential backoff on drop (§11.4).
    private func runLive(into continuation: AsyncStream<PriceTick>.Continuation) async {
        let url = environment.pricesWebSocketURL
        var attempt = 0
        while !Task.isCancelled {
            let ws = URLSession.shared.webSocketTask(with: url)
            wsTask = ws
            ws.resume()
            do {
                try await ws.send(.string(subscribeFrame()))
                attempt = 0
                while !Task.isCancelled {
                    let message = try await ws.receive()
                    if let tick = Self.decodeTick(message) { continuation.yield(tick) }
                }
            } catch {
                // Connection failed/dropped — fall through to backoff + reconnect.
            }
            ws.cancel(with: .goingAway, reason: nil)
            if wsTask === ws { wsTask = nil }
            if Task.isCancelled { break }

            attempt += 1
            let delayMs = min(1000 * (1 << min(attempt, 4)), 15_000)   // 2s,4s,…,15s cap
            try? await Task.sleep(for: .milliseconds(delayMs))
        }
        continuation.finish()
    }

    /// Subscribe frame our gateway expects: `{"type":"subscribe","assets":["BTC","ETH"]}`.
    private func subscribeFrame() -> String {
        let list = assets.map { "\"\($0.uppercased())\"" }.joined(separator: ",")
        return "{\"type\":\"subscribe\",\"assets\":[\(list)]}"
    }

    private static func decodeTick(_ message: URLSessionWebSocketTask.Message) -> PriceTick? {
        let data: Data
        switch message {
        case .string(let text): data = Data(text.utf8)
        case .data(let d):      data = d
        @unknown default:       return nil
        }
        return try? JSONDecoder().decode(PriceTick.self, from: data)
    }

    // MARK: Mock generator

    /// Demo walk: ±0.25% noise per 0.8s step with a gentle pull back toward the seed, so the price
    /// stays plausible over a long demo instead of drifting without bound. Stablecoins don't move.
    /// `changePct24h` is nil — the merge keeps the snapshot's real-looking 24h figure.
    private static func runMock(assets: [String], seeds: [String: Double],
                                into continuation: AsyncStream<PriceTick>.Continuation) async {
        let anchors: [String: Double] = Dictionary(uniqueKeysWithValues: assets.map { asset in
            (asset, seeds[asset.uppercased()] ?? seedPrice(asset))
        })
        var prices = anchors
        let formatter = ISO8601DateFormatter()
        while !Task.isCancelled {
            for asset in assets {
                let anchor = anchors[asset] ?? seedPrice(asset)
                let last = prices[asset] ?? anchor
                let next: Double
                if isStable(asset) {
                    next = anchor
                } else {
                    let noise = Double.random(in: -0.0025...0.0025)
                    let pull = (anchor - last) / anchor * 0.05
                    next = max(0.01, last * (1 + noise + pull))
                }
                prices[asset] = next
                continuation.yield(PriceTick(
                    asset: asset,
                    price: next,
                    changePct24h: nil,
                    ts: formatter.string(from: Date())
                ))
            }
            try? await Task.sleep(for: .milliseconds(800))
        }
        continuation.finish()
    }

    private static func isStable(_ asset: String) -> Bool {
        ["USDT", "USDC"].contains(asset.uppercased())
    }

    private static func seedPrice(_ asset: String) -> Double {
        switch asset.uppercased() {
        case "BTC":  return 9_540_000
        case "ETH":  return 318_000
        case "USDT": return 92
        case "SOL":  return 14_200
        case "TON":  return 610
        default:     return 1_000
        }
    }
}
