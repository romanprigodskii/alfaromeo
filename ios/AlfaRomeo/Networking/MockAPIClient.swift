import Foundation

/// Default client — returns rich demo fixtures from ``MockData`` so the whole app runs without a
/// backend. Profile-scoped methods switch between the personal and business fixtures.
struct MockAPIClient: APIClient {
    // Auth
    func signIn(phone: String, code: String) async throws -> AuthSession {
        AuthSession(user: MockData.user, accessToken: "mock-token-2035")
    }
    func currentUser() async throws -> User { MockData.user }

    // Identity
    func profiles() async throws -> [Profile] { MockData.profiles }
    func membership(profileId: String) async throws -> Membership { MockData.membership(profileId) }
    func subscription(profileId: String) async throws -> Subscription { MockData.subscription(profileId) }

    // Money
    func accounts(profileId: String) async throws -> [Account] { MockData.accounts(profileId) }
    func cards(profileId: String) async throws -> [Card] { MockData.cards(profileId) }
    func cardOrders(profileId: String) async throws -> [CardOrder] { MockData.cardOrders(profileId) }
    func transactions(profileId: String) async throws -> [Transaction] { MockData.transactions(profileId) }

    // Mobile
    func mobilePlan(profileId: String) async throws -> MobilePlan? { MockData.mobilePlan(profileId) }

    // Pricing
    func prices(assets: [String]) async throws -> [PriceTick] { MockData.prices(assets) }
    func candles(asset: String, range: CandleRange) async throws -> [PriceCandle] { MockData.candles(asset, range: range) }

    // Crypto
    func cryptoWallets(profileId: String) async throws -> [CryptoWallet] { MockData.cryptoWallets(profileId) }
    func orders(profileId: String) async throws -> [Order] { MockData.orders(profileId) }
    func deposits(profileId: String) async throws -> [Deposit] { MockData.deposits(profileId) }

    // Business
    func business(profileId: String) async throws -> Business? { MockData.business(profileId) }
    func counterparties(businessProfileId: String) async throws -> [Counterparty] { MockData.counterparties(businessProfileId) }
    func invoices(businessProfileId: String) async throws -> [Invoice] { MockData.invoices(businessProfileId) }

    // AI
    func aiStream(prompt: String, profileId: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AIStreamClient(mode: .mock).stream(prompt: prompt, profileId: profileId)
    }
}
