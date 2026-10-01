import Foundation

/// USD/₽ for converting direct-exchange USDT quotes to ₽ (§11.4). Same source as the backend's
/// `FxService` — the ЦБ РФ daily fix via cbr-xml-daily.ru — so app ₽ numbers agree with the server
/// once it is back. Chain: ЦБ → CoinGecko USDT/₽ (market) → last good rate (UserDefaults) → constant.
/// Never throws: there is always *a* rate, and ``Rate/origin`` says how trustworthy it is.
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

    /// Last-resort constant (matches the demo USDT seed), used only before any rate was ever fetched.
    static let fallbackRate: Double = 92

    let session: URLSession

    init(session: URLSession = ExchangeFeed.restSession) {
        self.session = session
    }

    func usdRub() async -> Rate {
        if let rate = try? await cbr() {
            Self.save(rate)
            return rate
        }
        if let rate = try? await market() {
            Self.save(rate)
            return rate
        }
        if let cached = Self.cached() { return cached }
        return Rate(usdRub: Self.fallbackRate, previous: nil, asOf: nil, origin: .fallback)
    }

    // MARK: Sources

    /// `GET https://www.cbr-xml-daily.ru/daily_json.js` → `Valute.USD.Value / Nominal`.
    private func cbr() async throws -> Rate {
        struct Daily: Decodable {
            struct Currency: Decodable {
                let nominal: Double
                let value: Double
                let previous: Double?
                enum CodingKeys: String, CodingKey { case nominal = "Nominal", value = "Value", previous = "Previous" }
            }
            let date: String
            let valute: [String: Currency]
            enum CodingKeys: String, CodingKey { case date = "Date", valute = "Valute" }
        }
        guard let url = URL(string: "https://www.cbr-xml-daily.ru/daily_json.js") else { throw APIError.invalidResponse }
        let daily: Daily = try await getJSON(url)
        guard let usd = daily.valute["USD"], usd.nominal > 0 else { throw APIError.invalidResponse }
        let value = usd.value / usd.nominal
        guard Self.plausible(value) else { throw APIError.invalidResponse }   // reject NaN / 0 / garbage
        let previous = usd.previous.map { $0 / usd.nominal }.flatMap { Self.plausible($0) ? $0 : nil }
        return Rate(usdRub: value, previous: previous,
                    asOf: ISO8601DateFormatter().date(from: daily.date), origin: .cbr)
    }

    /// CoinGecko `tether.rub` — a market USDT/₽ (~0.1% off the ЦБ fix), rate-limited, so second choice.
    private func market() async throws -> Rate {
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

    // MARK: Cache (last good rate survives relaunches / offline starts)

    private static let rateKey = "AR_FX_USDRUB"
    private static let previousKey = "AR_FX_USDRUB_PREV"
    private static let asOfKey = "AR_FX_USDRUB_ASOF"

    private static func save(_ rate: Rate) {
        let defaults = UserDefaults.standard
        defaults.set(rate.usdRub, forKey: rateKey)
        defaults.set(rate.previous ?? 0, forKey: previousKey)
        defaults.set((rate.asOf ?? Date()).timeIntervalSince1970, forKey: asOfKey)
    }

    private static func cached() -> Rate? {
        let defaults = UserDefaults.standard
        let value = defaults.double(forKey: rateKey)
        guard plausible(value) else { return nil }
        let previous = defaults.double(forKey: previousKey)
        let asOf = defaults.double(forKey: asOfKey)
        return Rate(usdRub: value, previous: plausible(previous) ? previous : nil,
                    asOf: asOf > 0 ? Date(timeIntervalSince1970: asOf) : nil, origin: .cached)
    }

    // MARK: HTTP

    private func getJSON<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
