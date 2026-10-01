import Foundation

/// One ЦБ РФ currency, normalised to ₽ per **one** unit (`Value / Nominal` — ЦБ quotes some currencies
/// per 10 or 100 units, e.g. KZT, AMD, JPY).
struct FXQuote: Codable, Hashable, Sendable {
    let code: String
    let name: String
    let numCode: String
    let perUnit: Double
    /// The previous fixing, also per one unit — gives the day change.
    let previousPerUnit: Double?

    var changePct: Double? {
        guard let previousPerUnit, previousPerUnit > 0 else { return nil }
        return (perUnit - previousPerUnit) / previousPerUnit * 100
    }
}

/// The ЦБ РФ daily fixing: every currency it quotes, for one effective date (`Date` can be tomorrow —
/// ЦБ publishes the next day's rate around 17:00 MSK).
struct CBRTable: Codable, Hashable, Sendable {
    let date: Date?
    let previousDate: Date?
    let quotes: [String: FXQuote]
}

/// Network layer for fiat FX (§11.4). Same source as the backend's `FxService` — the ЦБ РФ daily fix via
/// cbr-xml-daily.ru — so app ₽ numbers agree with the server. ``cbrTable()`` is the ONE fetch of that
/// file; ``FXRateService`` owns it (cache, refresh, all currencies) and ``usdRub()`` reads USD from it.
/// Never throws from ``usdRub()``: there is always *a* rate, and ``Rate/origin`` says how trustworthy it is.
struct FxRateClient: Sendable {
    struct Rate: Sendable, Hashable {
        enum Origin: Sendable, Hashable { case cbr, market, cached, fallback }

        let usdRub: Double
        /// Previous ЦБ fix — gives USDT its ₽ day change. Nil for non-ЦБ origins.
        let previous: Double?
        let asOf: Date?
        let origin: Origin

        var changePct: Double? {
            guard let previous, previous > 0 else { return nil }
            return (usdRub - previous) / previous * 100
        }
    }

    /// Last-resort USD/₽ — the seed ЦБ fix, used only before any rate was ever fetched.
    static let fallbackRate: Double = seedTable.quotes["USD"]?.perUnit ?? 83.2454

    let session: URLSession

    init(session: URLSession = ExchangeFeed.restSession) {
        self.session = session
    }

    /// USD/₽ for the crypto exchange leg: ЦБ (shared with every fiat screen via ``FXRateService``) →
    /// CoinGecko USDT/₽ → cached ЦБ → seed.
    func usdRub() async -> Rate {
        await FXRateService.shared.usdRubRate()
    }

    // MARK: Sources

    /// `GET https://www.cbr-xml-daily.ru/daily_json.js` → every `Valute`, `Value / Nominal`. Entries with
    /// NaN / 0 / negative values are dropped; a payload without a plausible USD is rejected.
    func cbrTable() async throws -> CBRTable {
        struct Daily: Decodable {
            struct Currency: Decodable {
                let numCode: String?
                let name: String?
                let nominal: Double
                let value: Double
                let previous: Double?
                enum CodingKeys: String, CodingKey {
                    case numCode = "NumCode", name = "Name", nominal = "Nominal", value = "Value", previous = "Previous"
                }
            }
            let date: String
            let previousDate: String?
            let valute: [String: Currency]
            enum CodingKeys: String, CodingKey { case date = "Date", previousDate = "PreviousDate", valute = "Valute" }
        }
        guard let url = URL(string: "https://www.cbr-xml-daily.ru/daily_json.js") else { throw APIError.invalidResponse }
        let daily: Daily = try await getJSON(url)
        var quotes: [String: FXQuote] = [:]
        for (key, c) in daily.valute {
            guard c.nominal.isFinite, c.nominal > 0, c.value.isFinite, c.value > 0 else { continue }
            let perUnit = c.value / c.nominal
            guard perUnit.isFinite, perUnit > 0 else { continue }
            let previous = c.previous.flatMap { $0.isFinite && $0 > 0 ? $0 / c.nominal : nil }
            let code = key.uppercased()
            quotes[code] = FXQuote(code: code, name: c.name ?? code, numCode: c.numCode ?? "",
                                   perUnit: perUnit, previousPerUnit: previous)
        }
        guard let usd = quotes["USD"], Self.plausible(usd.perUnit) else { throw APIError.invalidResponse }
        let iso = ISO8601DateFormatter()
        return CBRTable(date: iso.date(from: daily.date),
                        previousDate: daily.previousDate.flatMap { iso.date(from: $0) },
                        quotes: quotes)
    }

    /// CoinGecko `tether.rub` — a market USDT/₽ (~0.1% off the ЦБ fix), rate-limited, so second choice.
    func market() async throws -> Rate {
        struct Row: Decodable { let rub: Double? }
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=tether&vs_currencies=rub") else {
            throw APIError.invalidResponse
        }
        let rows: [String: Row] = try await getJSON(url)
        guard let rub = rows["tether"]?.rub, Self.plausible(rub) else { throw APIError.invalidResponse }
        return Rate(usdRub: rub, previous: nil, asOf: Date(), origin: .market)
    }

    /// Sanity band for a USD/₽ rate — rejects NaN, 0 and garbage before it multiplies every price.
    private static func plausible(_ value: Double) -> Bool { (20...500).contains(value) }

    // MARK: Seed (real ЦБ fix for 02.10.2026 — honest offline values, labelled with their date)

    static let seedTable: CBRTable = {
        let rows: [(String, String, String, Double, Double?)] = [
            ("USD", "Доллар США", "840", 83.2454, 83.5588),
            ("EUR", "Евро", "978", 94.5252, nil),
            ("CNY", "Китайский юань", "156", 12.4028, nil),
            ("AED", "Дирхам ОАЭ", "784", 22.6672, nil),
            ("TRY", "Турецкая лира", "949", 1.69978, nil),
            ("KZT", "Казахстанский тенге", "398", 0.188825, nil),
            ("AMD", "Армянский драм", "051", 0.22944, nil),
            ("RSD", "Сербский динар", "941", 0.801854, nil),
            ("GBP", "Фунт стерлингов", "826", 110.5915, nil),
            ("BYN", "Белорусский рубль", "933", 27.7014, nil),
            ("JPY", "Японская иена", "392", 0.52637, nil),
        ]
        let iso = ISO8601DateFormatter()
        return CBRTable(
            date: iso.date(from: "2026-10-02T11:30:00+03:00"),
            previousDate: iso.date(from: "2026-10-01T11:30:00+03:00"),
            quotes: Dictionary(uniqueKeysWithValues: rows.map {
                ($0.0, FXQuote(code: $0.0, name: $0.1, numCode: $0.2, perUnit: $0.3, previousPerUnit: $0.4))
            })
        )
    }()

    // MARK: HTTP

    private func getJSON<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
