import Foundation

/// Live crypto price ticks over `URLSessionWebSocketTask` (§11.4, §11.9).
///
/// - `.live` connects to **our** backend `/ws/prices` (not Binance/CoinGecko directly, §11.1):
///   subscribes to the asset set, parses ₽ ``PriceTick`` frames, and reconnects with exponential
///   backoff. This is the real path the demo's «Live prices» toggle uses.
/// - `.mock` runs a local random-walk generator (the default this phase / offline fallback).
/// - `.binance` / `.coinCap` remain direct-exchange skeletons (build the subscribe frame / URL) but
///   intentionally do NOT connect — the architecture routes prices through our backend instead.
///
/// Confined to `@MainActor` (its callers already are), so the mutable task/socket state needs no
/// extra synchronization and the type is `Sendable` without `@unchecked`.
@MainActor
final class PriceSocket {
    enum Source: Sendable { case mock, live, binance, coinCap }

    let source: Source
    let assets: [String]
    let environment: APIEnvironment

    private var generator: Task<Void, Never>?
    private var liveTask: Task<Void, Never>?
    private var wsTask: URLSessionWebSocketTask?

    init(source: Source = .mock, assets: [String], environment: APIEnvironment = .current) {
        self.source = source
        self.assets = assets
        self.environment = environment
    }

    /// A stream of ticks. For `.mock`, ticks arrive ~every 0.8s; `.live` streams real backend ticks
    /// (with auto-reconnect); the direct-exchange skeletons finish immediately.
    func ticks() -> AsyncStream<PriceTick> {
        AsyncStream { continuation in
            switch source {
            case .mock:
                let assets = self.assets
                let task = Task { await Self.runMock(assets: assets, into: continuation) }
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
            case .binance, .coinCap:
                // Adapter shape exists (binanceSubscribeFrame / coinCapURL) but we do not connect —
                // prices flow through our backend (`.live`), not the exchange directly (§11.1).
                continuation.finish()
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

    private static func runMock(assets: [String],
                                into continuation: AsyncStream<PriceTick>.Continuation) async {
        var prices: [String: Double] = Dictionary(uniqueKeysWithValues: assets.map { ($0, seedPrice($0)) })
        let formatter = ISO8601DateFormatter()
        while !Task.isCancelled {
            for asset in assets {
                let last = prices[asset] ?? seedPrice(asset)
                let drift = Double.random(in: -0.012...0.012)
                let next = max(0.01, last * (1 + drift))
                prices[asset] = next
                continuation.yield(PriceTick(
                    asset: asset,
                    price: next,
                    changePct24h: drift * 100,
                    ts: formatter.string(from: Date())
                ))
            }
            try? await Task.sleep(for: .milliseconds(800))
        }
        continuation.finish()
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

    // MARK: Direct-exchange adapters (skeleton — not connected; prices route via our backend)

    /// Binance combined-stream subscribe frame, e.g. `btcusdt@trade` (§11.4).
    func binanceSubscribeFrame() -> String {
        let params = assets.map { "\"\($0.lowercased())usdt@trade\"" }.joined(separator: ",")
        return "{\"method\":\"SUBSCRIBE\",\"params\":[\(params)],\"id\":1}"
    }

    /// CoinCap prices WebSocket URL for the configured assets (§11.4).
    func coinCapURL() -> URL? {
        let ids = assets.map { coinCapId($0) }.joined(separator: ",")
        return URL(string: "wss://ws.coincap.io/prices?assets=\(ids)")
    }

    private func coinCapId(_ asset: String) -> String {
        switch asset.uppercased() {
        case "BTC":  return "bitcoin"
        case "ETH":  return "ethereum"
        case "USDT": return "tether"
        case "SOL":  return "solana"
        case "TON":  return "toncoin"
        default:     return asset.lowercased()
        }
    }
}
