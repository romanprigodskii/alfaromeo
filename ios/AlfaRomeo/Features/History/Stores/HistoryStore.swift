import SwiftUI
import Observation

/// Shared, in-memory История state for the whole module (§9.4 / §10.7).
///
/// **Why a module-level shared store** (mirrors ``CardsStore`` / ``CryptoStore``): the contract API is
/// read-only fixtures, and the route destinations (`HistoryRoute.operationDetail/.budgetAnalytics/…`)
/// are independent view instances pushed onto the *home* `NavigationStack`, so there's no shared
/// ancestor inside the module to inject into. A `@MainActor @Observable` singleton, held via `@State`
/// in each screen, lets a manually-added expense, a re-categorized operation, a created category, and
/// an opened dispute all reflect live across the feed, the detail, and the analytics — within the
/// session. It hydrates once per profile from the ``APIClient``; every mutation below is a demo
/// simulation (no operations backend yet), so session edits are dropped on profile switch (§5.3).
@MainActor
@Observable
final class HistoryStore {
    static let shared = HistoryStore()

    /// Fixtures for the active profile (read-only seed).
    private(set) var seeded: [Transaction] = []
    private(set) var accounts: [Account] = []

    /// Manual expenses added this session (§9.4 «ручной учёт»), newest-first.
    private(set) var added: [Transaction] = []
    /// Per-operation category override, keyed by transaction id. The `Transaction` contract carries no
    /// `category` field, so the chosen category lives here instead of mutating the contract (§10.7).
    private(set) var overrides: [String: String] = [:]   // txId → CategoryRef.id (builtin rawValue / custom id)
    /// User-defined categories (§9.4 «добавить категорию»).
    private(set) var customCategories: [CustomCategory] = []
    /// Dispute tickets opened from operations — the «Обращения» source (see ``DisputeTicket``).
    private(set) var tickets: [DisputeTicket] = []

    private(set) var didLoad = false

    private var loadedProfileId: String?
    private var seq = 0

    private init() {}

    // MARK: - Load (once per profile)

    func load(api: any APIClient, profileId: String, force: Bool = false) async {
        guard !profileId.isEmpty, force || loadedProfileId != profileId else { return }
        let switching = loadedProfileId != profileId
        async let acctR = (try? await api.accounts(profileId: profileId)) ?? []
        async let txR   = (try? await api.transactions(profileId: profileId)) ?? []
        let (a, t) = await (acctR, txR)
        accounts = a
        seeded = t
        // New profile → drop the previous profile's session edits so nothing bleeds across a switch
        // (§5.3); same paradigm as CardsStore reloading its fixtures.
        if switching {
            added = []; overrides = [:]; customCategories = []; tickets = []
        }
        loadedProfileId = profileId
        didLoad = true
    }

    // MARK: - Feed / analytics source

    /// The unified operation set the feed and analytics read: fixtures + this session's manual entries.
    var allTransactions: [Transaction] { added + seeded }

    /// Newest operation instant — the feed's «now» anchor and the default date for a new manual expense
    /// (so it lands at the top of the future-dated demo timeline rather than under the real wall clock).
    var referenceDate: Date? { BudgetAnalytics.referenceDate(allTransactions) }

    func transaction(id: String) -> Transaction? { allTransactions.first { $0.id == id } }

    // MARK: - Categories

    var builtinRefs: [CategoryRef] { TransactionCategory.allCases.map { CategoryRef($0) } }
    var customRefs: [CategoryRef] { customCategories.map { CategoryRef($0) } }
    /// Every category offered in the picker / catalog: built-ins first, then the user's own.
    var allCategories: [CategoryRef] { builtinRefs + customRefs }

    func categoryRef(id: String) -> CategoryRef? {
        if let custom = customCategories.first(where: { $0.id == id }) { return CategoryRef(custom) }
        if let builtin = TransactionCategory(rawValue: id) { return CategoryRef(builtin) }
        return nil
    }

    /// Resolve an operation's category: an explicit override if set, else the §10.7 auto-classifier.
    func category(for tx: Transaction) -> CategoryRef {
        if let id = overrides[tx.id], let ref = categoryRef(id: id) { return ref }
        return CategoryRef(TransactionCategory.classify(tx))
    }

    // MARK: - Mutations

    /// Record a manual expense (§9.4). It joins ``allTransactions`` immediately, so it shows in the feed
    /// and is counted in analytics under the chosen category. Defaults to the active currency (₽).
    @discardableResult
    func addExpense(amount: Double, category: CategoryRef, note: String?, date: Date, profileId: String) -> Transaction {
        seq += 1
        let tx = Transaction(
            id: "man_\(seq)",
            profileId: profileId,
            kind: .payment,
            status: .completed,
            amount: -abs(amount),
            currency: "RUB",
            counterparty: (note?.isEmpty == false) ? note : nil,
            fee: nil,
            fxRate: nil,
            createdAt: HistoryDocuments.iso(date)
        )
        added.insert(tx, at: 0)
        overrides[tx.id] = category.id   // honor the explicit pick (don't re-classify a manual entry)
        return tx
    }

    /// Persist a category choice for an operation (§9.4 «категория редактируемая»).
    func setCategory(txId: String, ref: CategoryRef) { overrides[txId] = ref.id }

    @discardableResult
    func addCustomCategory(title: String, icon: String, tintHex: UInt32) -> CustomCategory {
        seq += 1
        let category = CustomCategory(id: "custom_\(seq)", title: title, iconName: icon, tintHex: tintHex)
        customCategories.append(category)
        return category
    }

    /// Open a dispute for an operation, returning the (idempotent) ticket. Reused by «Обращения» later.
    @discardableResult
    func dispute(_ tx: Transaction, category: CategoryRef) -> DisputeTicket {
        if let existing = tickets.first(where: { $0.txId == tx.id }) { return existing }
        seq += 1
        let ticket = DisputeTicket(
            id: "DSP-\(String(format: "%05d", 24_000 + seq))",
            txId: tx.id,
            counterparty: tx.counterparty,
            categoryTitle: category.title,
            amount: tx.amount,
            currency: tx.currency,
            filedStatus: .received,
            createdAt: Date()
        )
        tickets.insert(ticket, at: 0)
        return ticket
    }

    func ticket(forTx txId: String) -> DisputeTicket? { tickets.first { $0.txId == txId } }
}
