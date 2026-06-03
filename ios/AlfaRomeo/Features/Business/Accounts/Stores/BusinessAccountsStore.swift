import Foundation
import Observation

/// Shared, in-memory state for the business **Счета/РКО** section (§8.2) — and the source the
/// **Дашборд** reads its "баланс по счетам" from, so the two tabs never disagree.
///
/// Mirrors the ``AcquiringStore`` / ``TeamStore`` pattern: a `@MainActor @Observable` singleton held via
/// `@State` in each screen, hydrated once per business profile from the read-only ``APIClient`` (юрлицо +
/// счета + операции для выписки). It does **not** copy money figures locally — balances are the contract
/// ``Account`` values; the only derivation is the ₽ valuation of foreign/stablecoin balances, taken from
/// the **same** live price book as the Crypto Hub (``LivePriceService``). USD and the stablecoins
/// (USDT/USDC) are $-pegged, so they're valued at the live USDT→₽ rate (§2.4 «стейблы как опер. валюта»).
@MainActor
@Observable
final class BusinessAccountsStore {
    static let shared = BusinessAccountsStore()

    private(set) var business: Business?
    private(set) var accounts: [Account] = []
    /// Business operations behind the statement («выписка») — the real `transactions` slice.
    private(set) var operations: [Transaction] = []

    private(set) var didLoad = false
    private(set) var loadFailed = false

    private var loadedProfileId: String?

    private init() {}

    var businessName: String { business?.name ?? "Бизнес" }

    // MARK: - Load (once per business profile)

    func load(api: any APIClient, profileId: String, force: Bool = false) async {
        guard !profileId.isEmpty, force || loadedProfileId != profileId else { return }
        do {
            let biz = try await api.business(profileId: profileId)
            let accs = try await api.accounts(profileId: profileId)
            let ops = (try? await api.transactions(profileId: profileId)) ?? []
            business = biz
            accounts = accs
            operations = ops.sorted { $0.createdAt > $1.createdAt }
            loadFailed = false
            didLoad = true
            loadedProfileId = profileId          // commit only on success → a failed load can retry
        } catch {
            loadFailed = true
            didLoad = true
        }
    }

    // MARK: - Live ₽ valuation (§2.4 — same source as Crypto Hub)

    /// Live ₽ rate for one unit of a currency. ₽ is 1:1; USD and the stablecoins are $-pegged and priced
    /// off the live USDT→₽ tick; any other (crypto) symbol falls through to the price book directly.
    func rubRate(currency: String) -> Double {
        switch currency.uppercased() {
        case "RUB":                  return 1
        case "USD", "USDT", "USDC":  return LivePriceService.shared.price("USDT")
        default:                     return LivePriceService.shared.price(currency)
        }
    }

    /// ₽ equivalent of an account's native balance at the live rate.
    func rubValue(_ account: Account) -> Double { account.balance * rubRate(currency: account.currency) }

    // MARK: - Derivations

    /// All accounts as row view-models with their live ₽ value, биг-balances first.
    var items: [BusinessAccountItem] {
        accounts
            .map { BusinessAccountItem(account: $0, rubValue: rubValue($0)) }
            .sorted { $0.rubValue > $1.rubValue }
    }

    func items(in group: BusinessAccountGroup) -> [BusinessAccountItem] {
        items.filter { $0.group == group }
    }

    /// Groups that actually have accounts, in display order (rubles → multicurrency → treasury).
    var populatedGroups: [BusinessAccountGroup] {
        BusinessAccountGroup.allCases.filter { !items(in: $0).isEmpty }
    }

    /// Total ₽ across every account (₽ + multicurrency + treasury at the live rate) — the dashboard's
    /// «баланс по счетам» and the Счета hero share this one figure.
    var totalRub: Double { items.reduce(0) { $0 + $1.rubValue } }

    var settlementRub: Double { items(in: .rubles).reduce(0) { $0 + $1.rubValue } }
    var multicurrencyRub: Double { items(in: .multicurrency).reduce(0) { $0 + $1.rubValue } }
    var treasuryRub: Double { items(in: .treasury).reduce(0) { $0 + $1.rubValue } }

    /// Native total held in the crypto treasury (stablecoins ≈ $), for the «… USDT» sub-line.
    var treasuryStableTotal: Double { items(in: .treasury).reduce(0) { $0 + $1.balance } }
    var accountCount: Int { accounts.count }
}
