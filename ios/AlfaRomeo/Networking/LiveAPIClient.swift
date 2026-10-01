import Foundation

/// Live backend client (skeleton). Holds the `URLSession` + base URL from ``APIEnvironment`` and a
/// generic request helper; every method throws ``APIError/notImplemented`` until endpoints are
/// wired (Phase 0.3+). The AI stream returns an SSE skeleton stream.
struct LiveAPIClient: APIClient {
    let environment: APIEnvironment
    let session: URLSession

    init(environment: APIEnvironment = .current, session: URLSession = .shared) {
        self.environment = environment
        self.session = session
    }

    func signIn(phone: String, code: String) async throws -> AuthSession { throw APIError.notImplemented }
    func currentUser() async throws -> User { throw APIError.notImplemented }

    func profiles() async throws -> [Profile] { throw APIError.notImplemented }
    func membership(profileId: String) async throws -> Membership { throw APIError.notImplemented }
    func subscription(profileId: String) async throws -> Subscription { throw APIError.notImplemented }

    func accounts(profileId: String) async throws -> [Account] { throw APIError.notImplemented }
    func cards(profileId: String) async throws -> [Card] { throw APIError.notImplemented }
    func cardOrders(profileId: String) async throws -> [CardOrder] { throw APIError.notImplemented }
    func transactions(profileId: String) async throws -> [Transaction] { throw APIError.notImplemented }

    func mobilePlan(profileId: String) async throws -> MobilePlan? { throw APIError.notImplemented }

    // MARK: Pricing (§11.4) — first real backend data. ₽ equivalent is computed server-side.

    /// `GET /prices?assets=BTC,ETH` → ₽ snapshot. When the backend is unreachable, ``LivePriceService``
    /// falls back to public exchanges directly (``ExchangeFeed``).
    func prices(assets: [String]) async throws -> [PriceTick] {
        let list = assets.joined(separator: ",")
        return try await get("prices", query: [URLQueryItem(name: "assets", value: list)])
    }

    /// `GET /prices/:asset/candles?range=7d` → historical ₽ OHLC candles.
    func candles(asset: String, range: CandleRange) async throws -> [PriceCandle] {
        let path = "prices/\(asset.uppercased())/candles"
        return try await get(path, query: [URLQueryItem(name: "range", value: range.rawValue)])
    }

    func cryptoWallets(profileId: String) async throws -> [CryptoWallet] { throw APIError.notImplemented }
    func orders(profileId: String) async throws -> [Order] { throw APIError.notImplemented }
    func deposits(profileId: String) async throws -> [Deposit] { throw APIError.notImplemented }

    func business(profileId: String) async throws -> Business? { throw APIError.notImplemented }
    func counterparties(businessProfileId: String) async throws -> [Counterparty] { throw APIError.notImplemented }
    func invoices(businessProfileId: String) async throws -> [Invoice] { throw APIError.notImplemented }

    func aiStream(prompt: String, profileId: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AIStreamClient(mode: .live, baseURL: environment.baseURL).stream(prompt: prompt, profileId: profileId)
    }

    // MARK: Generic request

    /// Build a request for `path` (joined onto the base URL) with optional query + profile scoping.
    private func endpoint(_ path: String, query: [URLQueryItem] = [], profileId: String? = nil) -> URLRequest {
        var components = URLComponents(
            url: environment.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty { components?.queryItems = query }
        let url = components?.url ?? environment.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let profileId { request.setValue(profileId, forHTTPHeaderField: "X-Profile-Id") }
        return request
    }

    /// Perform a GET and decode JSON, mapping transport/HTTP/decoding failures to ``APIError``.
    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], profileId: String? = nil) async throws -> T {
        let request = endpoint(path, query: query, profileId: profileId)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(status: http.statusCode) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}
