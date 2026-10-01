import Foundation
import Observation
import UIKit

/// Official ЦБ РФ exchange rates for every fiat currency the app shows (§11.4): currency accounts' ₽
/// equivalents, the Home total, business Счета, transfers abroad. Same style as ``LivePriceService`` —
/// a `@MainActor @Observable` singleton every screen reads, so all ₽ figures use one rate book.
///
/// Chain: ЦБ (cbr-xml-daily.ru, via ``FxRateClient/cbrTable()``) → the last good table (UserDefaults,
/// survives relaunches) → the seed (a real ЦБ fix, dated). Reads never return 0. Refreshes when stale
/// (≥ 1 h) and on every return to foreground; ``LivePriceService`` takes its USD/₽ from here too, so the
/// ЦБ file is fetched once for the whole app.
@MainActor
@Observable
final class FXRateService {
    static let shared = FXRateService()

    enum Source: Sendable, Hashable { case cbr, cache, seed }

    /// The current ЦБ table (all currencies, ₽ per one unit).
    private(set) var table: CBRTable
    private(set) var source: Source
    private(set) var lastFetch: Date?

    /// True when the table came from ЦБ during this session.
    var isLive: Bool { source == .cbr }
    /// Effective date of the fixing.
    var asOf: Date? { table.date }

    private static let staleAfter: TimeInterval = 3600
    private static let cacheKey = "AR_FX_CBR_TABLE"
    private static let fetchedAtKey = "AR_FX_CBR_FETCHED_AT"

    private let client = FxRateClient()
    @ObservationIgnored private var inflight: Task<Void, Never>?
    @ObservationIgnored private var lastAttempt = Date.distantPast
    @ObservationIgnored private var foregroundObserver: NSObjectProtocol?

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
           let cached = try? JSONDecoder().decode(CBRTable.self, from: data), cached.quotes["USD"] != nil {
            table = cached
            source = .cache
            let at = UserDefaults.standard.double(forKey: Self.fetchedAtKey)
            lastFetch = at > 0 ? Date(timeIntervalSince1970: at) : nil
        } else {
            table = FxRateClient.seedTable
            source = .seed
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in await FXRateService.shared.refresh() }
        }
    }

    // MARK: - Reads

    /// ЦБ quote for a currency code (current table, else the seed).
    func quote(_ code: String) -> FXQuote? {
        let key = code.uppercased()
        return table.quotes[key] ?? FxRateClient.seedTable.quotes[key]
    }

    /// Fiat known to ЦБ (or ₽). Crypto tickers (BTC, USDT…) are not fiat.
    func isFiat(_ code: String) -> Bool {
        code.uppercased() == "RUB" || quote(code) != nil
    }

    /// ₽ per one unit. `RUB` → 1; unknown → 1 (never 0).
    func rate(_ code: String) -> Double {
        code.uppercased() == "RUB" ? 1 : (quote(code)?.perUnit ?? 1)
    }

    func rubValue(_ amount: Double, currency: String) -> Double { amount * rate(currency) }

    func convert(_ amount: Double, from: String, to: String) -> Double {
        amount * rate(from) / rate(to)
    }

    // MARK: - Labels

    /// `02.10` — Moscow date of the fixing (a device west of Moscow would otherwise show the day before).
    var dateText: String {
        guard let asOf else { return "—" }
        return Self.dateFormatter.string(from: asOf)
    }

    /// `курс ЦБ на 02.10`
    var label: String { "курс ЦБ на \(dateText)" }

    /// `1 USD = 83,25 ₽` (4 decimals for sub-ruble units like KZT).
    func rateText(_ code: String) -> String {
        let r = rate(code)
        let digits = MoneyFormat.number(r, minFractionDigits: 2, maxFractionDigits: r < 10 ? 4 : 2)
        return "1 \(code.uppercased()) = \(digits)\u{00A0}₽"
    }

    /// `▲ 0,38 %` / `▼ 0,38 %` vs the previous fixing, nil when unknown.
    func changeText(_ code: String) -> String? {
        guard let pct = quote(code)?.changePct, pct.isFinite else { return nil }
        let arrow = pct >= 0 ? "▲" : "▼"
        return "\(arrow)\u{00A0}\(MoneyFormat.percent(abs(pct), maxFractionDigits: 2))"
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(identifier: "Europe/Moscow")
        f.dateFormat = "dd.MM"
        return f
    }()

    // MARK: - Lifecycle

    /// Idempotent; safe from `.task` on every appearance (no fetch while fresh).
    func start() async { await refresh() }

    /// Fetch the ЦБ table unless this session already has a fresh one. Concurrent callers share one
    /// request; 2 retries with backoff; a failure keeps the current table (never 0, never throws).
    func refresh(force: Bool = false) async {
        if let inflight { await inflight.value; return }
        if !force, source == .cbr, let lastFetch, Date().timeIntervalSince(lastFetch) < Self.staleAfter { return }
        // Offline: don't hammer ЦБ from every screen's `.task` — one attempt per minute.
        if !force, source != .cbr, Date().timeIntervalSince(lastAttempt) < 60 { return }
        lastAttempt = Date()
        let client = self.client
        let task = Task { [weak self] in
            for attempt in 0..<3 {
                if attempt > 0 { try? await Task.sleep(for: .milliseconds(500 * attempt)) }
                if let fresh = try? await client.cbrTable() {
                    self?.adopt(fresh)
                    return
                }
            }
        }
        inflight = task
        await task.value
        inflight = nil
    }

    /// USD/₽ for ``LivePriceService``'s exchange leg: live ЦБ → market USDT/₽ → cached/seed ЦБ.
    func usdRubRate() async -> FxRateClient.Rate {
        await refresh()
        let usd = quote("USD")
        let value = usd?.perUnit ?? FxRateClient.fallbackRate
        if source == .cbr {
            return .init(usdRub: value, previous: usd?.previousPerUnit, asOf: table.date, origin: .cbr)
        }
        if let market = try? await client.market() { return market }
        return .init(usdRub: value, previous: usd?.previousPerUnit, asOf: table.date,
                     origin: source == .cache ? .cached : .fallback)
    }

    private func adopt(_ fresh: CBRTable) {
        table = fresh
        source = .cbr
        let now = Date()
        lastFetch = now
        if let data = try? JSONEncoder().encode(fresh) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: Self.fetchedAtKey)
        }
    }
}
