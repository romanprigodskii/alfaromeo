import Foundation

/// Result of a successful sign-in.
struct AuthSession: Codable, Hashable, Sendable {
    let user: User
    let accessToken: String
}

/// The networking contract. All methods are async and profile-scoped where relevant — every request
/// runs in the context of the active `profileId` (§5.3, §11.1).
///
/// Two implementations: ``MockAPIClient`` (default, rich fixtures) and ``LiveAPIClient`` (URLSession
/// skeleton). The live crypto tick stream is ``PriceSocket``; the AI stream is ``AIStreamClient``.
protocol APIClient: Sendable {
    // MARK: Auth (§11.2 Auth/KYC)
    func signIn(phone: String, code: String) async throws -> AuthSession
    func currentUser() async throws -> User

    // MARK: Identity / profiles (§11.2 Identity, Subscriptions)
    func profiles() async throws -> [Profile]
    func membership(profileId: String) async throws -> Membership
    func subscription(profileId: String) async throws -> Subscription

    // MARK: Money — profile-scoped (§11.2 Accounts, Cards, Payments)
    func accounts(profileId: String) async throws -> [Account]
    func cards(profileId: String) async throws -> [Card]
    func cardOrders(profileId: String) async throws -> [CardOrder]
    func transactions(profileId: String) async throws -> [Transaction]

    // MARK: Mobile (§11.2 Mobile/MVNO)
    func mobilePlan(profileId: String) async throws -> MobilePlan?

    // MARK: Pricing — REST snapshot + candles; live stream via ``PriceSocket`` (§11.4)
    func prices(assets: [String]) async throws -> [PriceTick]
    func candles(asset: String, range: CandleRange) async throws -> [PriceCandle]

    // MARK: Crypto (§11.2 Crypto, Deposits/Staking)
    func cryptoWallets(profileId: String) async throws -> [CryptoWallet]
    func orders(profileId: String) async throws -> [Order]
    func deposits(profileId: String) async throws -> [Deposit]

    // MARK: Business — minimal slice (§11.2 Business)
    func business(profileId: String) async throws -> Business?
    func counterparties(businessProfileId: String) async throws -> [Counterparty]
    func invoices(businessProfileId: String) async throws -> [Invoice]

    // MARK: AI orchestration — SSE stream (§11.7)
    func aiStream(prompt: String, profileId: String) -> AsyncThrowingStream<AIStreamEvent, Error>
}
