import Foundation
import Observation

// MARK: - Instruments

/// One Moscow Exchange instrument shown in «Биржа» → «Акции»: TQBR shares, TQOB ОФЗ and gold
/// (GLDRUB_TOM, currency market). `engine/market/board` are the ISS path pieces.
struct MoexInstrument: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable { case share, bond, metal }

    let secid: String
    let title: String
    /// Short exchange label under the name («SBER», «ОФЗ 26238», «GLDRUB»).
    let ticker: String
    /// Plain monogram for ``GlyphCircle`` (no fake logos).
    let monogram: String
    let kind: Kind
    /// Bonds: nominal in ₽ (ISS quotes bonds in % of it).
    var faceValue: Double = 1000
    /// Bonds: maturity, for the detail screen.
    var maturity: String? = nil

    var id: String { secid }

    var engine: String { kind == .metal ? "currency" : "stock" }
    var market: String {
        switch kind {
        case .share: return "shares"
        case .bond:  return "bonds"
        case .metal: return "selt"
        }
    }
    var board: String {
        switch kind {
        case .share: return "TQBR"
        case .bond:  return "TQOB"
        case .metal: return "CETS"
        }
    }
    /// Unit the price refers to.
    var unitNote: String {
        switch kind {
        case .share: return "за акцию"
        case .bond:  return "за облигацию"
        case .metal: return "за грамм"
        }
    }

    // Tinkoff (TCSG) trades as «T» since 2024 (checked against ISS).
    static let shares: [MoexInstrument] = [
        .init(secid: "SBER", title: "Сбербанк", ticker: "SBER", monogram: "СБ", kind: .share),
        .init(secid: "GAZP", title: "Газпром", ticker: "GAZP", monogram: "ГП", kind: .share),
        .init(secid: "LKOH", title: "Лукойл", ticker: "LKOH", monogram: "ЛК", kind: .share),
        .init(secid: "YDEX", title: "Яндекс", ticker: "YDEX", monogram: "Я", kind: .share),
        .init(secid: "GMKN", title: "Норникель", ticker: "GMKN", monogram: "НН", kind: .share),
        .init(secid: "ROSN", title: "Роснефть", ticker: "ROSN", monogram: "РН", kind: .share),
        .init(secid: "MGNT", title: "Магнит", ticker: "MGNT", monogram: "М", kind: .share),
        .init(secid: "T", title: "Т-Технологии", ticker: "T", monogram: "Т", kind: .share),
    ]
    static let bonds: [MoexInstrument] = [
        .init(secid: "SU26238RMFS4", title: "ОФЗ 26238", ticker: "SU26238RMFS4", monogram: "ОФЗ",
              kind: .bond, maturity: "15.05.2041"),
        .init(secid: "SU26248RMFS3", title: "ОФЗ 26248", ticker: "SU26248RMFS3", monogram: "ОФЗ",
              kind: .bond, maturity: "16.05.2040"),
    ]
    static let metals: [MoexInstrument] = [
        .init(secid: "GLDRUB_TOM", title: "Золото", ticker: "GLDRUB_TOM", monogram: "Au", kind: .metal),
    ]
    static let all = shares + bonds + metals

    static func find(_ secid: String) -> MoexInstrument? { all.first { $0.secid == secid } }
}

// MARK: - Quotes

/// A quote as ISS reports it: `LAST` (or the previous close before the first trade) and
/// `LASTTOPREVPRICE` (day %). Bond prices are re-expressed in ₽ from % of nominal.
struct MoexQuote: Codable, Hashable, Sendable {
    let secid: String
    /// ₽ (bonds: per bond).
    let price: Double
    /// Day change vs the previous close, percentage points.
    let changePct: Double
    /// Bonds: price in % of nominal.
    var pricePct: Double? = nil
    /// Bonds: yield to maturity, %.
    var yield: Double? = nil
    /// `UPDATETIME`, Moscow time «HH:mm:ss».
    let updateTime: String
    /// `TRADINGSTATUS == "T"`.
    let trading: Bool
}

struct MoexSnapshot: Codable, Sendable {
    var quotes: [String: MoexQuote]
    /// ISS `SYSTIME` of the answer, Moscow time.
    var sysTime: String?
    var fetchedAt: Date
    /// Measured SYSTIME − freshest UPDATETIME while trading (ISS gives non-subscribers 15 min delay).
    var delayMinutes: Int?
}

/// Chart timeframes for an instrument: ISS candle intervals 10 / 60 / 24 / 7 (минуты, час, день, неделя).
enum MoexTimeframe: String, CaseIterable, Identifiable, Sendable {
    case day, week, month, year
    var id: String { rawValue }
    var title: String {
        switch self {
        case .day:   return "1Д"
        case .week:  return "1Н"
        case .month: return "1М"
        case .year:  return "1Г"
        }
    }
    var interval: Int {
        switch self {
        case .day:   return 10
        case .week:  return 60
        case .month: return 24
        case .year:  return 7
        }
    }
    var lookbackDays: Int {
        switch self {
        case .day:   return 5
        case .week:  return 8
        case .month: return 32
        case .year:  return 366
        }
    }
    var caption: String {
        switch self {
        case .day:   return "свечи по 10 минут"
        case .week:  return "часовые свечи"
        case .month: return "дневные свечи"
        case .year:  return "недельные свечи"
        }
    }
}

// MARK: - ISS client

/// The public, keyless MOEX ISS JSON API (iss.moex.com). Each block is `{columns:[…], data:[[…]]}`.
struct MoexISSClient: Sendable {
    static let base = "https://iss.moex.com/iss"

    enum Failure: Error { case badResponse, empty }

    func snapshot() async throws -> MoexSnapshot {
        // Sequential on purpose: ISS stalls parallel cold connections from one client (measured: three
        // concurrent requests often hit the timeout, three in a row on one keep-alive take ~1 s).
        let parts = [
            try await board(MoexInstrument.shares, extraSec: [], extraMarket: []),
            try await board(MoexInstrument.bonds, extraSec: ["FACEVALUE"], extraMarket: ["YIELD"]),
            try await board(MoexInstrument.metals, extraSec: [], extraMarket: []),
        ]

        var quotes: [String: MoexQuote] = [:]
        var sysTime: String?
        for part in parts {
            sysTime = [sysTime, part.sysTime].compactMap { $0 }.max()
            for q in part.quotes { quotes[q.secid] = q }
        }
        guard !quotes.isEmpty else { throw Failure.empty }
        return MoexSnapshot(quotes: quotes, sysTime: sysTime, fetchedAt: Date(),
                            delayMinutes: Self.delay(quotes: Array(quotes.values), sysTime: sysTime))
    }

    func candles(_ inst: MoexInstrument, timeframe: MoexTimeframe) async throws -> [PriceCandle] {
        let from = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -timeframe.lookbackDays, to: Date()) ?? Date()
        var c = URLComponents(string: "\(Self.base)/engines/\(inst.engine)/markets/\(inst.market)/boards/\(inst.board)/securities/\(inst.secid)/candles.json")!
        c.queryItems = [
            .init(name: "interval", value: String(timeframe.interval)),
            .init(name: "from", value: Self.dayFormatter.string(from: from)),
            .init(name: "iss.meta", value: "off"),
            .init(name: "iss.only", value: "candles"),
            .init(name: "iss.reverse", value: "true"),   // newest first, so a 500-row page keeps today
        ]
        let rows = Self.rows(try await fetch(c), "candles")
        let scale = inst.kind == .bond ? inst.faceValue / 100 : 1
        var out: [PriceCandle] = rows.reversed().compactMap { r in
            guard let o = r["open"] as? Double, let cl = r["close"] as? Double,
                  let h = r["high"] as? Double, let l = r["low"] as? Double,
                  let t = r["begin"] as? String else { return nil }
            return PriceCandle(t: t, o: o * scale, h: h * scale, l: l * scale, c: cl * scale,
                               v: r["volume"] as? Double)
        }
        // 1Д = the latest trading day; early in the morning session also the day before, so the
        // chart is never just three candles.
        if timeframe == .day {
            let days = out.map { String($0.t.prefix(10)) }.reduce(into: [String]()) { if $0.last != $1 { $0.append($1) } }
            if let last = days.last {
                let lastCount = out.filter { $0.t.hasPrefix(last) }.count
                let keep = Set(lastCount < 18 ? days.suffix(2) : [last])
                out = out.filter { keep.contains(String($0.t.prefix(10))) }
            }
        }
        guard !out.isEmpty else { throw Failure.empty }
        return out
    }

    // MARK: Private

    private struct BoardPart: Sendable { var quotes: [MoexQuote]; var sysTime: String? }

    private func board(_ insts: [MoexInstrument], extraSec: [String], extraMarket: [String]) async throws -> BoardPart {
        guard let first = insts.first else { return BoardPart(quotes: []) }
        var c = URLComponents(string: "\(Self.base)/engines/\(first.engine)/markets/\(first.market)/boards/\(first.board)/securities.json")!
        c.queryItems = [
            .init(name: "securities", value: insts.map(\.secid).joined(separator: ",")),
            .init(name: "iss.meta", value: "off"),
            .init(name: "iss.only", value: "securities,marketdata"),
            .init(name: "securities.columns", value: (["SECID", "PREVPRICE"] + extraSec).joined(separator: ",")),
            .init(name: "marketdata.columns", value: (["SECID", "LAST", "LASTTOPREVPRICE", "UPDATETIME",
                                                       "SYSTIME", "TRADINGSTATUS"] + extraMarket).joined(separator: ",")),
        ]
        let json = try await fetch(c)
        var prev: [String: (prev: Double?, face: Double?)] = [:]
        for r in Self.rows(json, "securities") {
            guard let id = r["SECID"] as? String else { continue }
            prev[id] = (r["PREVPRICE"] as? Double, r["FACEVALUE"] as? Double)
        }
        var quotes: [MoexQuote] = []
        var sysTime: String?
        for r in Self.rows(json, "marketdata") {
            guard let id = r["SECID"] as? String, let inst = MoexInstrument.find(id) else { continue }
            let last = r["LAST"] as? Double
            let prevClose = prev[id]?.prev
            guard let raw = last ?? prevClose, raw > 0 else { continue }
            let pct: Double
            if let last, let p = prevClose, p > 0 {
                pct = (r["LASTTOPREVPRICE"] as? Double) ?? (last - p) / p * 100
            } else {
                pct = 0   // no trade yet today: previous close, unchanged
            }
            let face = prev[id]?.face ?? inst.faceValue
            let isBond = inst.kind == .bond
            quotes.append(MoexQuote(secid: id,
                                    price: isBond ? raw * face / 100 : raw,
                                    changePct: pct,
                                    pricePct: isBond ? raw : nil,
                                    yield: isBond ? r["YIELD"] as? Double : nil,
                                    updateTime: r["UPDATETIME"] as? String ?? "",
                                    trading: (r["TRADINGSTATUS"] as? String) == "T"))
            if let s = r["SYSTIME"] as? String { sysTime = max(sysTime ?? s, s) }
        }
        return BoardPart(quotes: quotes, sysTime: sysTime)
    }

    private func fetch(_ c: URLComponents) async throws -> [String: Any] {
        guard let url = c.url else { throw Failure.badResponse }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure.badResponse
        }
        return json
    }

    /// `{columns, data}` → one dictionary per row (`NSNull` simply fails the `as?` casts).
    private static func rows(_ json: [String: Any], _ block: String) -> [[String: Any]] {
        guard let b = json[block] as? [String: Any],
              let cols = b["columns"] as? [String],
              let data = b["data"] as? [[Any]] else { return [] }
        return data.map { row in
            var d: [String: Any] = [:]
            for (k, v) in zip(cols, row) { d[k] = v }
            return d
        }
    }

    /// SYSTIME − the freshest UPDATETIME among trading instruments, in minutes (nil when closed).
    private static func delay(quotes: [MoexQuote], sysTime: String?) -> Int? {
        guard let sysTime, let sys = moscowFormatter.date(from: sysTime) else { return nil }
        let day = String(sysTime.prefix(10))
        let lags = quotes.filter(\.trading).compactMap { q -> TimeInterval? in
            guard let t = moscowFormatter.date(from: "\(day) \(q.updateTime)") else { return nil }
            let lag = sys.timeIntervalSince(t)
            return lag >= 0 ? lag : nil
        }
        guard let freshest = lags.min() else { return nil }
        return Int((freshest / 60).rounded())
    }

    static let moscow = TimeZone(identifier: "Europe/Moscow") ?? .current

    private static let moscowFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = moscow
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = moscow
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Feed

/// Live MOEX quotes for «Биржа» → «Акции». Chain: ISS (polled every 15 s while a screen is visible)
/// → the last good answer (UserDefaults, survives relaunches) → a seeded snapshot labelled «демо».
/// Candles are fetched per instrument and timeframe; offline they fall back to a seeded walk that the
/// chart caption calls «демо».
@MainActor
@Observable
final class MoexFeed {
    static let shared = MoexFeed()

    enum Source: Hashable, Sendable {
        /// Fresh ISS answer in this session.
        case live
        /// Last good answer from a previous fetch (offline now).
        case cache
        /// Seeded snapshot, no MOEX data at all.
        case demo
    }

    private(set) var snapshot: MoexSnapshot
    private(set) var source: Source
    /// The last ISS request failed (vs. simply not answered yet at launch).
    private(set) var lastFetchFailed = false
    private(set) var candles: [String: [PriceCandle]] = [:]
    private(set) var candleIsDemo: Set<String> = []
    private(set) var loadingCandles: Set<String> = []

    static let pollInterval: Duration = .seconds(15)
    private static let cacheKey = "AR_MOEX_SNAPSHOT"

    private let client = MoexISSClient()
    @ObservationIgnored private var lastAttempt = Date.distantPast

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
           let cached = try? JSONDecoder().decode(MoexSnapshot.self, from: data), !cached.quotes.isEmpty {
            snapshot = cached
            source = .cache
        } else {
            snapshot = Self.seed
            source = .demo
        }
    }

    // MARK: Reads

    func quote(_ secid: String) -> MoexQuote? { snapshot.quotes[secid] }

    var isLive: Bool { source == .live }
    var isTrading: Bool { snapshot.quotes.values.contains(where: \.trading) }

    /// Badge text: «MOEX · с задержкой 15 мин», «MOEX · торги закрыты», «MOEX · сохранено 10:42», «Демо-котировки».
    var badgeTitle: String {
        switch source {
        case .demo:
            return "Демо-котировки"
        case .cache:
            return "MOEX · сохранено \(Self.timeFormatter.string(from: snapshot.fetchedAt))"
        case .live:
            guard isTrading else { return "MOEX · торги закрыты" }
            guard let d = snapshot.delayMinutes, d >= 5 else { return "MOEX · онлайн" }
            return "MOEX · с задержкой \((10...20).contains(d) ? 15 : d) мин"
        }
    }

    /// One honest line for footers: what the user is looking at.
    var sourceNote: String {
        switch source {
        case .demo:
            return lastFetchFailed
                ? "Нет связи с Мосбиржей: показаны демо-котировки на 2 октября 2026 года, не для сделок."
                : "Загружаем котировки Мосбиржи. Пока показаны демо-котировки на 2 октября 2026 года."
        case .cache:
            return lastFetchFailed
                ? "Нет связи с Мосбиржей: последние полученные котировки. Обновим, как только связь вернётся."
                : "Последние сохранённые котировки, обновляем с Мосбиржи."
        case .live:
            return "Котировки Московской биржи (ISS). Без подписки биржа отдаёт данные с задержкой 15 минут, время московское."
        }
    }

    // MARK: Polling

    /// Polls ISS every 15 s until the calling `.task` is cancelled (the screen disappears).
    func poll() async {
        while !Task.isCancelled {
            await refresh()
            // Not live yet (cold start, offline): try again sooner than the regular 15 s.
            try? await Task.sleep(for: source == .live ? Self.pollInterval : .seconds(5))
        }
    }

    func refresh() async {
        // Several visible screens may poll at once (hub + detail): skip a request made seconds ago.
        guard Date().timeIntervalSince(lastAttempt) > 4 else { return }
        lastAttempt = Date()
        do {
            let fresh = try await client.snapshot()
            snapshot = fresh
            source = .live
            lastFetchFailed = false
            if let data = try? JSONEncoder().encode(fresh) {
                UserDefaults.standard.set(data, forKey: Self.cacheKey)
            }
        } catch {
            lastFetchFailed = true
            if source == .live { source = .cache }   // keep the last good answer, say so
        }
    }

    // MARK: Candles

    static func candleKey(_ secid: String, _ tf: MoexTimeframe) -> String { "\(secid)|\(tf.rawValue)" }

    func series(_ secid: String, _ tf: MoexTimeframe) -> [PriceCandle]? { candles[Self.candleKey(secid, tf)] }
    func seriesIsDemo(_ secid: String, _ tf: MoexTimeframe) -> Bool { candleIsDemo.contains(Self.candleKey(secid, tf)) }
    func isLoading(_ secid: String, _ tf: MoexTimeframe) -> Bool { loadingCandles.contains(Self.candleKey(secid, tf)) }

    func loadCandles(_ inst: MoexInstrument, _ tf: MoexTimeframe) async {
        let key = Self.candleKey(inst.secid, tf)
        loadingCandles.insert(key)
        defer { loadingCandles.remove(key) }
        do {
            candles[key] = try await client.candles(inst, timeframe: tf)
            candleIsDemo.remove(key)
        } catch {
            guard candles[key] == nil else { return }   // keep the last real series
            candles[key] = Self.demoCandles(secid: inst.secid, tf: tf, last: quote(inst.secid)?.price ?? 100)
            candleIsDemo.insert(key)
        }
    }

    // MARK: Seeds

    /// Real ISS values from 2 October 2026 (morning session), shown only when MOEX was never reachable.
    static let seed: MoexSnapshot = {
        func q(_ id: String, _ p: Double, _ pct: Double, pricePct: Double? = nil, yield: Double? = nil) -> MoexQuote {
            MoexQuote(secid: id, price: p, changePct: pct, pricePct: pricePct, yield: yield,
                      updateTime: "07:27:24", trading: false)
        }
        let list = [
            q("SBER", 276.15, -0.01), q("GAZP", 97.30, 0.14), q("LKOH", 5423.5, -0.2),
            q("YDEX", 3616.5, 0.25), q("GMKN", 117.0, 0.07), q("ROSN", 347.95, 0.06),
            q("MGNT", 1578.0, 0.29), q("T", 260.56, 0.14),
            q("SU26238RMFS4", 507.90, -0.01, pricePct: 50.79, yield: 16.45),
            q("SU26248RMFS3", 790.30, 0.1, pricePct: 79.03, yield: 16.73),
            q("GLDRUB_TOM", 11180, 0),
        ]
        return MoexSnapshot(quotes: Dictionary(uniqueKeysWithValues: list.map { ($0.secid, $0) }),
                            sysTime: "2026-10-02 07:42:24",
                            fetchedAt: Date(timeIntervalSince1970: 1_790_916_144), delayMinutes: 15)
    }()

    /// Deterministic walk ending at `last`, used only when ISS candles are unreachable (caption: «демо»).
    static func demoCandles(secid: String, tf: MoexTimeframe, last: Double) -> [PriceCandle] {
        var seed = UInt64(truncatingIfNeeded: secid.unicodeScalars.reduce(5381) { ($0 << 5) &+ $0 &+ Int($1.value) })
            &+ UInt64(tf.interval)
        func rnd() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(UInt32.max) - 0.5
        }
        let count = 48
        let vol = tf == .year ? 0.03 : tf == .month ? 0.012 : 0.004
        var closes: [Double] = [last]
        for _ in 1..<count { closes.append(closes.last! * (1 - rnd() * vol * 2)) }
        closes.reverse()
        return closes.enumerated().map { i, c in
            let o = i == 0 ? c : closes[i - 1]
            let wick = abs(rnd()) * vol * c
            return PriceCandle(t: "demo-\(i)", o: o, h: max(o, c) + wick, l: min(o, c) - wick, c: c)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm"
        return f
    }()
}
