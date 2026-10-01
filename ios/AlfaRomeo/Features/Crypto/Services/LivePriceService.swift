import Foundation
import Observation

/// The app's source of **real live prices** (§9.6 / §11.4). The app injects ``MockAPIClient``
/// app-wide, so this service reaches the network directly and walks an honest fallback chain, re-checked
/// in the background for the whole session:
///
/// 1. **Our backend** — REST snapshot via ``LiveAPIClient`` + the ``PriceSocket`` `.live` stream
///    (₽ priced server-side).
/// 2. **A public exchange directly** — ``ExchangeFeed`` (Binance market-data mirror → Bybit →
///    CoinGecko), USD quotes × курс ЦБ (``FxRateClient``). Binance WebSocket, with REST polling every
///    5 s whenever the stream goes quiet or is blocked.
/// 3. **Demo** — the local ``PriceSocket`` `.mock` walk, seeded from the last real prices; the chain is
///    retried every 30 s, so prices upgrade back to live on their own.
///
/// The active leg is ``source`` (``isLive`` stays for existing callers: backend OR exchange), so the UI
/// can say where a number comes from. Shared singleton (like ``CardsStore``) so the dashboard, asset
/// detail, and every flow read one price book. `@MainActor`-confined.
@MainActor
@Observable
final class LivePriceService {
    static let shared = LivePriceService()

    /// Latest tick per asset, keyed by UPPERCASE symbol. Always ₽.
    private(set) var ticks: [String: PriceTick] = [:]
    /// Where the current prices come from. `.demo` until the first snapshot resolves.
    private(set) var source: PriceSource = .demo
    /// The live leg has gone quiet (no fresh price for ``Timing/staleAfter``) — the badge turns amber.
    private(set) var isStale = false
    private(set) var lastUpdate: Date?
    /// USD/₽ the exchange leg converts with (курс ЦБ) — for provenance rows.
    private(set) var fx: FxRateClient.Rate?

    /// True on a real market feed — our backend **or** a public exchange; false → demo walk.
    var isLive: Bool { source.isLive }

    private enum Timing {
        static let staleAfter: TimeInterval = 30        // no fresh price → amber badge
        static let streamQuiet: TimeInterval = 8        // WS silent this long → REST fill
        static let pollEvery: Duration = .seconds(5)
        static let demoRetry: Duration = .seconds(30)
        static let backendProbeEvery: TimeInterval = 120
        static let fxRefreshEvery: TimeInterval = 3 * 3600
        static let aggregatorGap: TimeInterval = 60      // CoinGecko 429s on bursts
        static let flushEvery: TimeInterval = 1          // coalesce stream ticks → ≤ 1 render/s
    }

    /// Debug override, like `AR_BACKEND_PORT`: `-AR_PRICE_SOURCE demo|exchange` (launch arg → UserDefaults)
    /// pins the chain to that leg so the demo / exchange paths can be shown without pulling the network.
    private var forcedLeg: String? { UserDefaults.standard.string(forKey: "AR_PRICE_SOURCE")?.lowercased() }

    /// Exchange leg also prices USDC from its own pair (backend tracks only ``CryptoCatalog/pricedSymbols``).
    private static let exchangeAssets = CryptoCatalog.pricedSymbols + ["USDC"]
    private static let iso = ISO8601DateFormatter()

    private let backend: LiveAPIClient
    private let exchange = ExchangeFeed()
    private let fxClient = FxRateClient()

    @ObservationIgnored private var bootTask: Task<Void, Never>?
    @ObservationIgnored private var supervisor: Task<Void, Never>?
    @ObservationIgnored private var pending: [String: PriceTick] = [:]
    @ObservationIgnored private var lastFlush = Date.distantPast
    @ObservationIgnored private var lastStreamTick = Date.distantPast
    @ObservationIgnored private var lastAggregatorCall = Date.distantPast
    @ObservationIgnored private var fxFetchedAt = Date.distantPast

    private init() {
        // Short timeout: a dead backend host must not stall the chain (the default is 60 s).
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        config.timeoutIntervalForResource = 6
        config.waitsForConnectivity = false
        backend = LiveAPIClient(session: URLSession(configuration: config))
    }

    // MARK: - Reads

    var hasData: Bool { !ticks.isEmpty }

    /// Live ₽ price for an asset. USDC uses its own exchange tick when present, else USDT (both ≈ $1);
    /// unknown assets fall back to a seed so the portfolio never renders 0 (§11.4).
    func price(_ asset: String) -> Double {
        let key = asset.uppercased()
        if let tick = ticks[key] { return tick.price }
        if key == "USDC" { return ticks["USDT"]?.price ?? Self.seed("USDT") }
        return Self.seed(key)
    }

    func change24h(_ asset: String) -> Double? {
        let key = asset.uppercased()
        if let tick = ticks[key] { return tick.changePct24h }
        if key == "USDC" { return ticks["USDT"]?.changePct24h }
        return nil
    }

    func rubValue(asset: String, qty: Double) -> Double { qty * price(asset) }

    /// Live **USD/₽** rate for the portfolio's ₽/$ display toggle (§9.6). USDT is dollar-pegged and
    /// priced in ₽ (server-side, or курс ЦБ on the exchange leg), so its ₽ price *is* the USD/₽ rate.
    /// To show a ₽ value in $, divide it by this. Always positive (price falls back to a seed).
    var usdRub: Double { price("USDT") }

    // MARK: - Lifecycle

    /// Resolve the first snapshot (so the header has a value instantly), then keep a background
    /// supervisor streaming and re-checking the chain. Idempotent and race-free — concurrent callers
    /// await the same bootstrap. Safe to call from `.task` on every appearance.
    func start() async {
        if supervisor == nil {
            let boot = Task { await self.resolve() }
            bootTask = boot
            supervisor = Task { [weak self] in
                await boot.value
                await self?.supervise()
            }
        }
        await bootTask?.value
    }

    func stop() {
        supervisor?.cancel()
        supervisor = nil
        bootTask = nil
    }

    // MARK: - Chain

    /// Walk backend → exchange → demo and adopt the first leg that answers. Backend, exchange and FX
    /// are fetched concurrently so a dead backend costs no extra latency.
    private func resolve() async {
        pending.removeAll()
        let assets = CryptoCatalog.pricedSymbols
        let exchangeAssets = Self.exchangeAssets
        let backend = self.backend, exchange = self.exchange, fxClient = self.fxClient
        let needFx = fx == nil || Date().timeIntervalSince(fxFetchedAt) > Timing.fxRefreshEvery
        let allowAggregator = aggregatorAllowed
        let forced = forcedLeg

        async let backendSnap = backend.prices(assets: assets)
        async let exchangeSnap = exchange.snapshot(assets: exchangeAssets, includeAggregator: allowAggregator)
        async let freshFx = Self.fetchFx(fxClient, needed: needFx)

        if let rate = await freshFx { adoptFx(rate) }

        if forced != "demo", forced != "exchange", let live = try? await backendSnap, !live.isEmpty {
            merge(live)
            source = .backend
            markFresh()
            return
        }
        if forced != "demo" {
            do {
                let snap = try await exchangeSnap
                noteAggregator(used: snap.venue == .coinGecko)
                apply(snap)
                return
            } catch {
                noteAggregator(used: allowAggregator)
            }
        }
        // Everything is down → demo. Keep the last real prices if we had them (the walk continues from
        // there); only a cold start shows the reference snapshot.
        if ticks.isEmpty { merge(MockData.prices(assets)) }
        source = .demo
        isStale = false
    }

    private func supervise() async {
        while !Task.isCancelled {
            switch source {
            case .backend:  await runBackend()
            case .exchange: await runExchange()
            case .demo:     await runDemo()
            }
            if Task.isCancelled { break }
            await resolve()
        }
    }

    /// Backend leg: ₽ ticks over `/ws/prices`; REST-poll the backend when the socket is quiet.
    private func runBackend() async {
        let socket = PriceSocket(source: .live, assets: CryptoCatalog.pricedSymbols)
        let consumer = Task { [weak self] in
            for await tick in socket.ticks() {
                guard let self else { break }
                self.lastStreamTick = Date()
                self.enqueue(tick)
            }
        }
        defer { consumer.cancel(); socket.stop() }
        await watch(poll: { await self.pollBackend() }, upgrade: nil)
    }

    /// Exchange leg: Binance miniTicker stream; REST (Binance → Bybit → CoinGecko) whenever it's quiet;
    /// periodically checks whether our backend is back.
    private func runExchange() async {
        let stream = exchange.stream(assets: Self.exchangeAssets)
        let consumer = Task { [weak self] in
            for await quote in stream {
                guard let self else { break }
                self.lastStreamTick = Date()
                self.enqueue(self.tick(from: quote))
                if self.source != .exchange(.binance) { self.source = .exchange(.binance) }
            }
        }
        defer { consumer.cancel() }
        await watch(poll: { await self.pollExchange() }, upgrade: { await self.backendIsBack() })
    }

    /// Demo leg: the local walk for a while, then back to `resolve()` to try the live legs again.
    private func runDemo() async {
        let socket = PriceSocket(source: .mock, assets: CryptoCatalog.pricedSymbols,
                                 seeds: ticks.mapValues(\.price))
        let consumer = Task { [weak self] in
            for await tick in socket.ticks() {
                guard let self else { break }
                self.enqueue(tick)
            }
        }
        defer { consumer.cancel(); socket.stop() }
        try? await Task.sleep(for: Timing.demoRetry)
    }

    /// Shared live-leg watchdog: every 5 s flush coalesced ticks, refresh FX when due, REST-poll when the
    /// stream is quiet, and flag staleness. Returns (→ re-resolve) after three failed polls in a row or
    /// when `upgrade` reports a better leg is back.
    private func watch(poll: () async -> Bool, upgrade: (() async -> Bool)?) async {
        var failures = 0
        var lastProbe = Date()
        while !Task.isCancelled {
            try? await Task.sleep(for: Timing.pollEvery)
            if Task.isCancelled { return }
            flush()
            if case .exchange = source, Date().timeIntervalSince(fxFetchedAt) > Timing.fxRefreshEvery {
                adoptFx(await fxClient.usdRub())
            }
            if Date().timeIntervalSince(lastStreamTick) > Timing.streamQuiet {
                failures = await poll() ? 0 : failures + 1
            } else {
                failures = 0
            }
            let stale = Date().timeIntervalSince(lastUpdate ?? .distantPast) > Timing.staleAfter
            if stale != isStale { isStale = stale }   // don't re-render observers on a no-op write
            if failures >= 3 { return }
            if let upgrade, Date().timeIntervalSince(lastProbe) > Timing.backendProbeEvery {
                lastProbe = Date()
                if await upgrade() { return }
            }
        }
    }

    private func pollBackend() async -> Bool {
        guard let live = try? await backend.prices(assets: CryptoCatalog.pricedSymbols), !live.isEmpty else {
            return false
        }
        merge(live)
        markFresh()
        return true
    }

    private func pollExchange() async -> Bool {
        let allow = aggregatorAllowed
        do {
            let snap = try await exchange.snapshot(assets: Self.exchangeAssets, includeAggregator: allow)
            noteAggregator(used: snap.venue == .coinGecko)
            apply(snap)
            return true
        } catch {
            noteAggregator(used: allow)
            return false
        }
    }

    private func backendIsBack() async -> Bool {
        guard forcedLeg != "exchange" else { return false }
        return (try? await backend.prices(assets: CryptoCatalog.pricedSymbols))?.isEmpty == false
    }

    // MARK: - Exchange → ₽

    /// Adopt an exchange USD snapshot: × курс ЦБ, plus USDT itself (= the rate, its day change = the ЦБ
    /// fix change) when the venue doesn't quote it.
    private func apply(_ snap: (venue: ExchangeVenue, quotes: [ExchangeQuote])) {
        var incoming = snap.quotes.map(tick(from:))
        if !snap.quotes.contains(where: { $0.asset == "USDT" }) {
            let rate = fx?.usdRub ?? FxRateClient.fallbackRate
            incoming.append(PriceTick(asset: "USDT", price: rate, changePct24h: fx?.changePct ?? 0,
                                      ts: Self.iso.string(from: Date())))
        }
        merge(incoming)
        source = .exchange(snap.venue)
        markFresh()
    }

    private func tick(from quote: ExchangeQuote) -> PriceTick {
        let rate = fx?.usdRub ?? FxRateClient.fallbackRate
        return PriceTick(asset: quote.asset, price: quote.usd * rate,
                         changePct24h: quote.changePct24h, ts: Self.iso.string(from: quote.ts))
    }

    /// Take a new USD/₽ rate and re-express the exchange-priced book with it (keeps every ₽ number on
    /// one rate after a ЦБ refresh).
    private func adoptFx(_ rate: FxRateClient.Rate) {
        let old = fx?.usdRub
        fx = rate
        fxFetchedAt = Date()
        guard case .exchange = source, let old, old > 0, old != rate.usdRub else { return }
        let k = rate.usdRub / old
        ticks = ticks.mapValues { t in
            let change = t.asset == "USDT" ? (rate.changePct ?? t.changePct24h) : t.changePct24h
            return PriceTick(asset: t.asset, price: t.price * k, changePct24h: change, ts: t.ts)
        }
    }

    private nonisolated static func fetchFx(_ client: FxRateClient, needed: Bool) async -> FxRateClient.Rate? {
        needed ? await client.usdRub() : nil
    }

    private var aggregatorAllowed: Bool { Date().timeIntervalSince(lastAggregatorCall) > Timing.aggregatorGap }
    private func noteAggregator(used: Bool) { if used { lastAggregatorCall = Date() } }

    // MARK: - Book

    /// Buffer a streamed tick; flush at most once a second so a busy stream doesn't re-render every
    /// price-reading view on each frame.
    private func enqueue(_ tick: PriceTick) {
        pending[tick.asset.uppercased()] = tick
        if Date().timeIntervalSince(lastFlush) >= Timing.flushEvery { flush() }
    }

    private func flush() {
        guard !pending.isEmpty else { return }
        let batch = Array(pending.values)
        pending.removeAll()
        lastFlush = Date()
        merge(batch)
        markFresh()
    }

    private func markFresh() {
        lastUpdate = Date()
        if isStale { isStale = false }
    }

    private func merge(_ incoming: [PriceTick]) {
        for tick in incoming {
            let key = tick.asset.uppercased()
            // Preserve a known 24h change if a streamed tick omits it (the demo walk never sets one).
            let change = tick.changePct24h ?? ticks[key]?.changePct24h
            ticks[key] = PriceTick(asset: key, price: tick.price, changePct24h: change, ts: tick.ts)
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
