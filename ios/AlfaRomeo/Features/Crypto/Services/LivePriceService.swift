import Foundation
import Observation

/// The Crypto hub's source of **real live prices** (§9.6 / §11.4). The app injects ``MockAPIClient``
/// app-wide, so this service reaches the backend directly — REST snapshot via ``LiveAPIClient`` and a
/// streaming ``PriceSocket`` — and degrades gracefully to the mock when the backend is unreachable, so
/// the demo always ticks (the live-or-mock decision the user picked).
///
/// Shared singleton (like ``CardsStore``) so the dashboard, asset detail, and every flow read one
/// ticking price book. `@MainActor`-confined: ``PriceSocket`` yields on the main actor.
@MainActor
@Observable
final class LivePriceService {
    static let shared = LivePriceService()

    /// Latest tick per asset, keyed by UPPERCASE symbol.
    private(set) var ticks: [String: PriceTick] = [:]
    /// True once a real backend response (REST or WS) has arrived; false → running on the mock fallback.
    private(set) var isLive = false
    private(set) var lastUpdate: Date?

    private let liveClient = LiveAPIClient()
    private var socket: PriceSocket?
    private var streamTask: Task<Void, Never>?
    private var didBootstrap = false

    private init() {}

    // MARK: - Reads

    var hasData: Bool { !ticks.isEmpty }

    /// Live ₽ price for an asset. USDC is priced 1:1 against USDT (both ≈ $1) since the backend tracks
    /// USDT; unknown assets fall back to a seed so the portfolio never renders 0 (§11.4).
    func price(_ asset: String) -> Double {
        let key = asset.uppercased()
        if key == "USDC" { return ticks["USDT"]?.price ?? Self.seed("USDT") }
        return ticks[key]?.price ?? Self.seed(key)
    }

    func change24h(_ asset: String) -> Double? {
        let key = asset.uppercased()
        if key == "USDC" { return ticks["USDT"]?.changePct24h }
        return ticks[key]?.changePct24h
    }

    func rubValue(asset: String, qty: Double) -> Double { qty * price(asset) }

    /// Live **USD/₽** rate for the portfolio's ₽/$ display toggle (§9.6). USDT is dollar-pegged and the
    /// backend prices it in ₽, so its ₽ price *is* the live USD/₽ rate (the spec's `usdRub`). To show a
    /// ₽ value in $, divide it by this. Always positive (price falls back to a seed), so division is safe.
    var usdRub: Double { price("USDT") }

    // MARK: - Lifecycle

    /// REST snapshot first (so the header has a value instantly), then start the stream. Idempotent —
    /// safe to call from `.task` on every appearance.
    func start() async {
        await bootstrap()
        startStreaming()
    }

    /// Fetch the ₽ snapshot. Prefer the live backend; fall back to the injected-style mock so the hub
    /// always has prices offline.
    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        if let live = try? await liveClient.prices(assets: CryptoCatalog.pricedSymbols), !live.isEmpty {
            merge(live)
            isLive = true
        } else {
            merge(MockData.prices(CryptoCatalog.pricedSymbols))   // offline fallback
            isLive = false
        }
    }

    /// Stream live ticks. If the snapshot proved the backend is up, use `.live`; otherwise use the
    /// local `.mock` generator so the UI still visibly ticks during a demo without a backend.
    private func startStreaming() {
        guard streamTask == nil else { return }
        let source: PriceSocket.Source = isLive ? .live : .mock
        let socket = PriceSocket(source: source, assets: CryptoCatalog.pricedSymbols)
        self.socket = socket
        streamTask = Task { [weak self] in
            for await tick in socket.ticks() {
                guard let self else { break }
                self.merge([tick])
                if source == .live { self.isLive = true }
                self.lastUpdate = Date()
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        socket?.stop()
        socket = nil
    }

    // MARK: - Private

    private func merge(_ incoming: [PriceTick]) {
        for tick in incoming {
            let key = tick.asset.uppercased()
            // Preserve a known 24h change if a streamed tick omits it (mock random-walk sets its own).
            if var existing = ticks[key], tick.changePct24h == nil {
                existing = PriceTick(asset: key, price: tick.price,
                                     changePct24h: existing.changePct24h, ts: tick.ts)
                ticks[key] = existing
            } else {
                ticks[key] = PriceTick(asset: key, price: tick.price,
                                       changePct24h: tick.changePct24h, ts: tick.ts)
            }
        }
        if lastUpdate == nil { lastUpdate = Date() }
    }

    private static func seed(_ asset: String) -> Double {
        switch asset.uppercased() {
        case "BTC":  return 9_540_000
        case "ETH":  return 318_000
        case "USDT", "USDC": return 92
        case "SOL":  return 14_200
        case "TON":  return 610
        default:     return 1_000
        }
    }
}
