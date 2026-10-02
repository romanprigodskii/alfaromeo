import Foundation

// MARK: - Shared contract with the app

/// Ключи снимка баланса в App Group. Пишет приложение (`AlfaRomeo/Core/WidgetSnapshot.swift`), читает
/// виджет. Строки продублированы намеренно: виджет не импортирует код приложения, держите их в синхроне.
enum WidgetShared {
    static let kind = "AlfaRomeoWidget"
    static let appGroup = "group.bank.alfa-romeo.demo"
    static let totalKey = "widget.balance.totalRub"
    static let updatedKey = "widget.balance.updatedAt"
}

// MARK: - Models

struct CoinQuote: Codable, Equatable {
    let ticker: String      // BTC
    let name: String        // Биткоин
    let rub: Double         // цена в ₽ по курсу ЦБ
    let changePct: Double   // изменение за 24 ч, п.п.
}

struct MarketSnapshot: Codable, Equatable {
    let quotes: [CoinQuote]
    let usdRub: Double
    let fetchedAt: Date

    func quote(_ ticker: String) -> CoinQuote? { quotes.first { $0.ticker == ticker } }
}

/// Общий ₽-баланс, который приложение посчитало на «Главной».
struct BalanceSnapshot: Equatable {
    let totalRub: Double
    let updatedAt: Date

    static func read() -> BalanceSnapshot? {
        guard let d = UserDefaults(suiteName: WidgetShared.appGroup),
              let total = d.object(forKey: WidgetShared.totalKey) as? Double,
              let ts = d.object(forKey: WidgetShared.updatedKey) as? Double else { return nil }
        return BalanceSnapshot(totalRub: total, updatedAt: Date(timeIntervalSince1970: ts))
    }
}

struct RatesEntry {
    let date: Date
    let market: MarketSnapshot?
    let balance: BalanceSnapshot?
    /// Живой запрос не прошёл, показана последняя удачная выборка.
    let marketIsCached: Bool

    /// Для галереи виджетов и плейсхолдера, пока нет данных.
    static let sample = RatesEntry(
        date: .now,
        market: MarketSnapshot(
            quotes: [
                CoinQuote(ticker: "BTC", name: "Биткоин", rub: 9_412_300, changePct: 1.24),
                CoinQuote(ticker: "ETH", name: "Эфир", rub: 312_450, changePct: -0.74),
            ],
            usdRub: 81.1, fetchedAt: .now),
        balance: BalanceSnapshot(totalRub: 1_284_530.45, updatedAt: .now),
        marketIsCached: false)
}

// MARK: - Market feed (Binance 24hr ticker × курс ЦБ)

enum MarketFeed {
    private static let coins: [(ticker: String, pair: String, name: String)] = [
        ("BTC", "BTCUSDT", "Биткоин"),
        ("ETH", "ETHUSDT", "Эфир"),
    ]
    /// Public market data, no key: `/api/v3/ticker/24hr?symbols=["BTCUSDT","ETHUSDT"]`.
    private static let tickerURL = URL(string:
        "https://data-api.binance.vision/api/v3/ticker/24hr?symbols=%5B%22BTCUSDT%22,%22ETHUSDT%22%5D")!
    private static let cbrURL = URL(string: "https://www.cbr-xml-daily.ru/daily_json.js")!
    private static let cacheKey = "widget.market.cache"

    private struct Ticker: Decodable {
        let symbol: String
        let lastPrice: String
        let priceChangePercent: String
    }

    private struct CBRDaily: Decodable {
        struct Rate: Decodable { let Value: Double }
        let Valute: [String: Rate]
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    /// Живые цены; при ошибке сети последняя удачная выборка (`cached == true`) или `nil`.
    /// USDT считается равным доллару; если ЦБ недоступен, берётся прошлый курс ЦБ из кэша.
    static func load(now: Date = .now) async -> (market: MarketSnapshot?, cached: Bool) {
        let previous = cached()
        do {
            async let tickersTask = fetch([Ticker].self, from: tickerURL)
            async let cbrTask = fetch(CBRDaily.self, from: cbrURL)
            let tickers = try await tickersTask
            let cbrUsd = (try? await cbrTask)?.Valute["USD"]?.Value
            guard let usdRub = cbrUsd ?? previous?.usdRub, usdRub > 0 else { throw URLError(.cannotParseResponse) }

            let quotes = coins.compactMap { coin -> CoinQuote? in
                guard let row = tickers.first(where: { $0.symbol == coin.pair }),
                      let usdt = Double(row.lastPrice), let pct = Double(row.priceChangePercent) else { return nil }
                return CoinQuote(ticker: coin.ticker, name: coin.name, rub: usdt * usdRub, changePct: pct)
            }
            guard !quotes.isEmpty else { throw URLError(.cannotParseResponse) }
            let snapshot = MarketSnapshot(quotes: quotes, usdRub: usdRub, fetchedAt: now)
            store(snapshot)
            return (snapshot, false)
        } catch {
            return (previous, true)
        }
    }

    private static func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func cached() -> MarketSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(MarketSnapshot.self, from: data)
    }

    private static func store(_ snapshot: MarketSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}

// MARK: - Formatting (same rules as the app's MoneyFormat: «1 234,50 ₽», «−0,74 %»)

enum WFormat {
    static let nbsp = "\u{00A0}"
    static let minus = "\u{2212}"

    /// `9 412 300 ₽` (без копеек) или `1 284 530,45 ₽`.
    static func rub(_ value: Double, kopecks: Bool = false) -> String {
        let p = rubParts(value, kopecks: kopecks)
        return p.integer + p.tail
    }

    /// Целая часть и хвост (`,45 ₽`) отдельно, чтобы копейки шли мельче, как в шапке «Главной».
    static func rubParts(_ value: Double, kopecks: Bool = true) -> (integer: String, tail: String) {
        let digits = kopecks ? 2 : 0
        let rounded = (abs(value) * pow(10, Double(digits))).rounded() / pow(10, Double(digits))
        let raw = String(format: "%.\(digits)f", rounded)
        let parts = raw.split(separator: ".")
        let sign = value < 0 && rounded > 0 ? minus : ""
        let integer = sign + group(String(parts[0]))
        let fraction = parts.count > 1 ? "," + parts[1] : ""
        return (integer, fraction + nbsp + "₽")
    }

    /// `+1,24 %`, `−0,74 %`, `0,00 %`.
    static func percent(_ points: Double) -> String {
        let rounded = (abs(points) * 100).rounded() / 100
        let body = String(format: "%.2f", rounded).replacingOccurrences(of: ".", with: ",")
        let sign = rounded == 0 ? "" : (points > 0 ? "+" : minus)
        return sign + body + nbsp + "%"
    }

    /// `14:05` сегодня, иначе `01.10, 14:05`.
    static func time(_ date: Date, now: Date = .now) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = Calendar.current.isDate(date, inSameDayAs: now) ? "HH:mm" : "dd.MM, HH:mm"
        return f.string(from: date)
    }

    private static func group(_ digits: String) -> String {
        var out = ""
        for (i, ch) in digits.reversed().enumerated() {
            if i > 0, i % 3 == 0 { out.append(nbsp) }
            out.append(ch)
        }
        return String(out.reversed())
    }
}
