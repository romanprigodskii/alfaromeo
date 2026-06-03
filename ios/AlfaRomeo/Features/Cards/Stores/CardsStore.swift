import SwiftUI
import Observation

/// Shared, in-memory Cards state for the whole module (§6).
///
/// **Why a module-level shared store:** the API is read-only fixtures and lives outside
/// `Features/Cards/`, and the route destinations (`CardsRoute.list/.detail/.order/.tracking`) are
/// independent view instances pushed onto the *home* `NavigationStack`, so there is no shared
/// ancestor inside the module to inject into. A `@MainActor @Observable` singleton, held via
/// `@State` in each screen, lets an order placed in the wizard, a freeze toggled in the detail, and a
/// delivery advancing on the tracking screen all reflect live in the carousel — without touching the
/// shell. It hydrates once per profile from the ``APIClient``; every mutation below is a demo
/// simulation (no PAN ever materialises client-side, §11.8).
@MainActor
@Observable
final class CardsStore {
    static let shared = CardsStore()

    private(set) var cards: [CardItem] = []
    private(set) var orders: [DeliveryOrder] = []
    private(set) var accounts: [Account] = []
    private(set) var wallets: [CryptoWallet] = []
    private(set) var recentOperations: [Transaction] = []
    private(set) var baseTier: Tier = .base
    private(set) var didLoad = false
    /// True when the last load threw — lets the UI show an error/retry state distinct from "no cards"
    /// (acceptance criterion 7 "ошибки"). `MockAPIClient` never throws, but a live client can.
    private(set) var loadFailed = false

    /// Set by a caller (e.g. the "Выпустить одноразовую" shortcut) before pushing `.order`, then
    /// consumed once by ``CardOrderView`` to preselect a product. Keeps `CardsRoute.order`
    /// parameter-free (so the cross-module Home rails keep compiling).
    var orderPreset: CardProduct?

    private var loadedProfileId: String?
    private var seq = 0

    private init() {}

    // MARK: - Load (once per profile)

    func load(api: any APIClient, profileId: String, force: Bool = false) async {
        guard !profileId.isEmpty, force || loadedProfileId != profileId else { return }
        do {
            // Cards are the essential fetch — its failure is a real error (criterion 7). The rest is
            // best-effort context that degrades gracefully.
            let c = try await api.cards(profileId: profileId)
            async let ordersR = (try? await api.cardOrders(profileId: profileId)) ?? []
            async let acctR   = (try? await api.accounts(profileId: profileId)) ?? []
            async let walletR = (try? await api.cryptoWallets(profileId: profileId)) ?? []
            async let txR     = (try? await api.transactions(profileId: profileId)) ?? []
            async let subR    = (try? await api.subscription(profileId: profileId))?.tier

            cards = c.map(CardItem.init(from:))
            let (o, a, w, t, tier) = await (ordersR, acctR, walletR, txR, subR)
            orders = o.map(DeliveryOrder.init(from:))
            accounts = a
            wallets = w
            recentOperations = t
            baseTier = tier ?? .base
            loadFailed = false
            didLoad = true
            loadedProfileId = profileId           // commit only on success → a failed load can retry
        } catch {
            loadFailed = true
            didLoad = true
        }
    }

    // MARK: - Lookups

    func card(id: String) -> CardItem? { cards.first { $0.id == id } }

    /// Resolve a route's card id, falling back to the default card so the cross-module Home rail
    /// (which pushes `.detail(cardId: "demo")`) still opens a real card.
    func routedCard(id: String) -> CardItem? { card(id: id) ?? defaultCard }

    var defaultCard: CardItem? { cards.first { $0.isDefault } ?? cards.first }

    func account(id: String?) -> Account? { accounts.first { $0.id == id } }
    func wallet(asset: String?) -> CryptoWallet? { wallets.first { $0.asset == asset } }
    func order(id: String) -> DeliveryOrder? { orders.first { $0.id == id } }

    /// Orders still on their way — the "В доставке" section + tracking entry. Keeps a delivered-but-
    /// not-yet-activated order visible (its plastic is still `.shipping`) so activation stays reachable.
    var inFlightOrders: [DeliveryOrder] {
        orders.filter { order in
            if order.status != .delivered { return true }
            if let id = order.cardId, card(id: id)?.state == .shipping { return true }
            return false
        }
    }

    /// Cards that count against the tier limit (everything except ephemeral burners).
    var primaryCards: [CardItem] { cards.filter { !$0.isBurner } }
    var burnerCards: [CardItem] { cards.filter { $0.isBurner } }

    /// Operations attributed to a card. The contract's `Transaction` isn't card-scoped, so the demo
    /// surfaces the profile's recent operations as the card's activity (§6.3 "история операций").
    func operations(for card: CardItem) -> [Transaction] { recentOperations }

    // MARK: - Mutations · management

    private func mutate(_ id: String, _ change: (inout CardItem) -> Void) {
        guard let i = cards.firstIndex(where: { $0.id == id }) else { return }
        change(&cards[i])
    }

    func setFrozen(_ frozen: Bool, cardId: String) {
        mutate(cardId) { if $0.state == .frozen || $0.state == .active { $0.state = frozen ? .frozen : .active } }
    }

    func setDefault(cardId: String) {
        for i in cards.indices { cards[i].isDefault = (cards[i].id == cardId) }
    }

    func changeDesign(_ designId: String, cardId: String) {
        mutate(cardId) { $0.designId = designId }
    }

    func addToWallet(cardId: String) {
        mutate(cardId) { $0.addedToWallet = true }
    }

    func setLimits(_ limits: CardLimits, cardId: String) {
        mutate(cardId) { $0.limits = limits }
    }

    func rebind(accountId: String?, asset: String?, cardId: String) {
        mutate(cardId) {
            if let accountId { $0.accountId = accountId }
            $0.assetLink = asset
        }
    }

    /// Re-issue: a fresh number, back to active (clears expired / compromised state). Refuses to act
    /// on an in-transit card so its DeliveryOrder can never be orphaned (delivery owns that lifecycle).
    func reissue(cardId: String) {
        mutate(cardId) {
            guard $0.state != .shipping, $0.state != .issuing else { return }
            $0.last4 = Self.randomLast4(); $0.state = .active; $0.addedToWallet = false
        }
    }

    func burn(cardId: String) {
        mutate(cardId) { $0.state = .burned; $0.burner?.used = true }
    }

    // MARK: - Mutations · issuance

    /// Issue a virtual (or crypto) card **instantly** (§6.2 step 3) and return it.
    @discardableResult
    func issueVirtual(product: CardProduct, designId: String, accountId: String?, asset: String?) -> CardItem {
        seq += 1
        let card = CardItem(
            id: "card_v\(seq)",
            accountId: accountId ?? accounts.first?.id ?? "acc",
            type: product.cardType,
            last4: Self.randomLast4(),
            state: .active,
            designId: designId,
            isDefault: cards.isEmpty,
            assetLink: asset,
            limits: .fresh,
            issuedAt: Date()
        )
        cards.append(card)
        return card
    }

    /// Order a plastic for an issued card: creates a `.shipping` plastic ``CardItem`` plus a
    /// trackable ``DeliveryOrder`` (§6.2 step 4–5). The plastic activates on arrival.
    @discardableResult
    func startPhysical(virtualCardId: String?, designId: String, accountId: String,
                       asset: String?, address: String, method: DeliveryMethod) -> DeliveryOrder {
        seq += 1
        let plastic = CardItem(
            id: "card_p\(seq)",
            accountId: accountId,
            type: .plastic,
            last4: Self.randomLast4(),
            state: .shipping,
            designId: designId,
            isDefault: false,
            assetLink: asset,
            limits: .fresh,
            issuedAt: Date()
        )
        cards.append(plastic)

        seq += 1
        let order = DeliveryOrder(
            id: "co_\(seq)",
            cardId: plastic.id,
            cardType: .plastic,
            designId: designId,
            status: .ordered,
            tracking: "RM-2035-\(String(format: "%06d", 100_000 + seq))",
            address: address,
            method: method,
            orderedAt: Date()
        )
        orders.append(order)
        return order
    }

    /// Generate a burner instantly (§6.1). Burners do **not** count against the tier card limit —
    /// they are ephemeral security tokens, available on every tier.
    @discardableResult
    func createBurner(mode: BurnerMode, merchant: String?, limit: Double, accountId: String) -> CardItem {
        seq += 1
        let card = CardItem(
            id: "card_b\(seq)",
            accountId: accountId,
            type: .disposable,
            last4: Self.randomLast4(),
            state: .active,
            designId: CardDesign.burner.id,
            isDefault: false,
            assetLink: nil,
            limits: .burner(limit: limit),
            issuedAt: Date(),
            burner: BurnerConfig(mode: mode, merchant: merchant, limit: limit, used: false)
        )
        cards.append(card)
        return card
    }

    // MARK: - Mutations · delivery

    /// Advance one stage (ordered → printing → shipping → delivered). Activation is separate.
    func advanceDelivery(orderId: String) {
        guard let i = orders.firstIndex(where: { $0.id == orderId }),
              let next = orders[i].status.next else { return }
        orders[i].status = next
    }

    func setDeliveryStatus(_ status: PhysicalCardStatus, orderId: String) {
        guard let i = orders.firstIndex(where: { $0.id == orderId }) else { return }
        orders[i].status = status
    }

    /// Activate on arrival (§6.2 "активация по прибытии"): marks delivered and flips the linked
    /// plastic card to active.
    func activate(orderId: String) {
        guard let i = orders.firstIndex(where: { $0.id == orderId }) else { return }
        orders[i].status = .delivered
        if let cardId = orders[i].cardId {
            mutate(cardId) { if $0.state == .shipping { $0.state = .active } }
        }
    }

    // MARK: - Mutations · money (Пополнить / Перевести demo)

    func topUp(_ amount: Double, accountId: String) { adjust(accountId, by: amount) }
    func transfer(_ amount: Double, accountId: String) { adjust(accountId, by: -amount) }

    private func adjust(_ accountId: String, by delta: Double) {
        guard let i = accounts.firstIndex(where: { $0.id == accountId }) else { return }
        let a = accounts[i]
        accounts[i] = Account(id: a.id, profileId: a.profileId, type: a.type,
                              currency: a.currency, balance: max(a.balance + delta, 0))
    }

    private static func randomLast4() -> String { String(format: "%04d", Int.random(in: 0...9_999)) }
}
