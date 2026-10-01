import SwiftUI
import Observation

/// Shared, in-memory state for the «Приумножить» hub (§10.6).
///
/// **Why a module-level shared store** (same rationale as `CardsStore`): the ``APIClient`` is
/// read-only fixtures, and the route destinations (`SavingsRoute.openDeposit/.stake/.detail`) are
/// independent views pushed onto the *home* `NavigationStack`, so there is no module ancestor to
/// inject into. A `@MainActor @Observable` singleton lets a deposit opened in the wizard appear live
/// in the hub list and goals top-ups reflect everywhere. It hydrates once per profile from the
/// ``APIClient`` (`deposits` / `cryptoWallets` / `subscription` / `prices`); every mutation is a demo
/// simulation. Live ₽ valuation of stakes folds in ``LivePriceService`` ticks (§11.4).
@MainActor
@Observable
final class SavingsStore {
    static let shared = SavingsStore()

    private(set) var deposits: [Deposit] = []        // активные вклады + стейки (API + локально открытые)
    private(set) var wallets: [CryptoWallet] = []     // балансы для пресетов суммы стейка
    private(set) var goals: [SavingsGoal] = []
    /// Options chosen when a ruble deposit was opened here. The ``Deposit`` contract has no fields for
    /// them, so they live beside it, keyed by deposit id. API deposits have no entry.
    private(set) var depositOptions: [String: DepositOptions] = [:]
    private(set) var baseTier: Tier = .base
    private(set) var didLoad = false
    private(set) var loadFailed = false

    /// REST ₽ snapshot (asset → ₽), fallback until a live tick lands (§11.4).
    private(set) var priceSnapshot: [String: Double] = [:]
    /// Live ₽ ticks (asset → ₽) from the app-wide ``LivePriceService`` — same numbers as «Биржа».
    var livePrices: [String: Double] { LivePriceService.shared.ticks.mapValues(\.price) }

    private var loadedProfileId: String?
    private var seq = 0

    private static let trackedAssets = ["BTC", "ETH", "USDT", "SOL", "TON"]

    /// Offline reference prices (₽) — keeps catalog cards + previews realistic before a load/tick.
    private static let referencePrices: [String: Double] = [
        "BTC": 9_540_000, "ETH": 318_000, "USDT": 92, "SOL": 14_200, "TON": 610,
    ]

    private init() {}

    // MARK: - Load (once per profile)

    func load(api: any APIClient, profileId: String, force: Bool = false) async {
        guard !profileId.isEmpty, force || loadedProfileId != profileId else { return }
        do {
            // Deposits are the essential fetch; the rest is best-effort context that degrades gracefully.
            let apiDeposits = try await api.deposits(profileId: profileId)
            async let walletsR = (try? await api.cryptoWallets(profileId: profileId)) ?? []
            async let tierR    = (try? await api.subscription(profileId: profileId))?.tier
            async let pricesR  = (try? await api.prices(assets: Self.trackedAssets)) ?? []

            let (w, tier, ticks) = await (walletsR, tierR, pricesR)
            // Preserve locally-opened deposits across a forced reload (don't drop user actions).
            let localOnly = deposits.filter { $0.profileId == profileId && $0.id.hasPrefix("dep_") }
            deposits = localOnly + apiDeposits
            wallets = w
            baseTier = tier ?? .base
            priceSnapshot = Dictionary(ticks.map { ($0.asset.uppercased(), $0.price) },
                                       uniquingKeysWith: { first, _ in first })
            if goals.isEmpty { goals = Self.seedGoals(profileId: profileId) }
            loadFailed = false
            didLoad = true
            loadedProfileId = profileId
        } catch {
            loadFailed = true
            didLoad = true
        }
    }

    // MARK: - Live prices (§11.4)

    /// Start the shared ``LivePriceService`` (idempotent — the hub and a pushed stake flow share it).
    func streamPrices() async {
        await LivePriceService.shared.start()
    }

    /// ₽ price for an asset: a live tick if present, else the REST snapshot, else the reference price.
    func price(for asset: String) -> Double {
        let key = asset.uppercased()
        return livePrices[key] ?? priceSnapshot[key] ?? Self.referencePrices[key] ?? 0
    }

    func rubValue(units: Double, asset: String) -> Double { units * price(for: asset) }

    // MARK: - Lookups

    func deposit(id: String) -> Deposit? { deposits.first { $0.id == id } }
    var rubleDeposits: [Deposit] { deposits.filter { $0.kind == .ruble } }
    var stakes: [Deposit] { deposits.filter { $0.kind == .stake } }
    func wallet(asset: String) -> CryptoWallet? {
        wallets.first { $0.asset.uppercased() == asset.uppercased() }
    }

    /// Best advertised APY across active products — the hub header teaser.
    var bestActiveApy: Double? { deposits.map(\.rateApy).max() }

    /// Total ₽ across active вклады + стейки (stakes valued live).
    var totalValueRub: Double {
        deposits.reduce(0) { sum, dep in
            switch dep.kind {
            case .ruble: return sum + dep.principal
            case .stake: return sum + rubValue(units: dep.principal, asset: dep.asset ?? "")
            }
        }
    }

    /// ₽ staked in-app toward the неквал-инвестор annual cap (300 000 ₽/год, §2.4). Demo
    /// simplification: counts only stakes opened here (`dep_s…`), treating pre-existing/API positions
    /// as prior-period — a production ledger would track the real calendar-year total per investor.
    func stakedRubThisYear(profileId: String) -> Double {
        deposits
            .filter { $0.kind == .stake && $0.profileId == profileId && $0.id.hasPrefix("dep_s") }
            .reduce(0) { $0 + rubValue(units: $1.principal, asset: $1.asset ?? "") }
    }

    // MARK: - Mutations · open (§10.6 flows)

    @discardableResult
    func openDeposit(profileId: String, product: DepositProduct,
                     amount: Double, termMonths: Int, apy: Double,
                     capitalize: Bool = false, topUp: Bool = false) -> Deposit {
        seq += 1
        let dep = Deposit(
            id: "dep_r\(seq)", profileId: profileId, kind: .ruble, asset: nil,
            principal: amount, rateApy: apy, term: termMonths,
            lockUntil: Self.iso(monthsFromNow: termMonths))
        deposits.insert(dep, at: 0)
        depositOptions[dep.id] = DepositOptions(
            capitalize: capitalize && product.allowsCapitalization,
            topUp: topUp && product.allowsTopUp)
        return dep
    }

    @discardableResult
    func openStake(profileId: String, product: StakeProduct,
                   units: Double, lockDays: Int, apy: Double) -> Deposit {
        seq += 1
        let dep = Deposit(
            id: "dep_s\(seq)", profileId: profileId, kind: .stake, asset: product.asset,
            principal: units, rateApy: apy, term: nil,
            lockUntil: lockDays > 0 ? Self.iso(daysFromNow: lockDays) : nil)
        deposits.insert(dep, at: 0)
        return dep
    }

    /// Top up a top-up-eligible ruble deposit (demo). `Deposit.principal` is `let`, so replace in place.
    func topUpDeposit(id: String, by amount: Double) {
        guard let i = deposits.firstIndex(where: { $0.id == id }), deposits[i].kind == .ruble else { return }
        let d = deposits[i]
        deposits[i] = Deposit(id: d.id, profileId: d.profileId, kind: d.kind, asset: d.asset,
                              principal: d.principal + amount, rateApy: d.rateApy,
                              term: d.term, lockUntil: d.lockUntil)
    }

    // MARK: - Mutations · goals (§10.6)

    func addGoal(_ goal: SavingsGoal) { goals.insert(goal, at: 0) }

    func topUpGoal(id: String, by amount: Double) {
        guard let i = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[i].current = min(goals[i].current + amount, goals[i].target)
    }

    func setAutoTopUp(id: String, monthly: Double?) {
        guard let i = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[i].autoTopUpMonthly = monthly
    }

    func nextGoalId() -> String { seq += 1; return "goal_\(seq)" }

    // MARK: - Seed

    private static func seedGoals(profileId: String) -> [SavingsGoal] {
        guard profileId == MockData.personalProfileId else { return [] }
        return [
            SavingsGoal(id: "goal_seed1", profileId: profileId, title: "Подушка безопасности",
                        emoji: "🛟", target: 300_000, current: 184_000, autoTopUpMonthly: 15_000),
            SavingsGoal(id: "goal_seed2", profileId: profileId, title: "Отпуск 2035",
                        emoji: "✈️", target: 200_000, current: 52_000, autoTopUpMonthly: nil),
        ]
    }

    // MARK: - Date helpers

    private static func iso(monthsFromNow months: Int) -> String {
        iso(Calendar.current.date(byAdding: .month, value: months, to: Date()) ?? Date())
    }
    private static func iso(daysFromNow days: Int) -> String {
        iso(Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date())
    }
    private static func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
}
