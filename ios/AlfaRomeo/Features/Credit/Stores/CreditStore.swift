import SwiftUI
import Observation

/// Shared, in-memory state for the Кредиты hub (§10.5).
///
/// **Why a module-level shared store** (same rationale as `SavingsStore`/`CardsStore`): the
/// ``APIClient`` is read-only fixtures with no credit data, and the route destinations
/// (`CreditRoute.prequal/.apply`) are independent views pushed onto the *home* `NavigationStack`, so
/// there's no module ancestor to inject into. A `@MainActor @Observable` singleton lets a credit
/// opened in the wizard appear live on the витрина and lets the simulator recompute the limit
/// everywhere at once. It self-seeds demo inputs/obligations once per profile; every mutation is a
/// simulation. The borrower's inputs + the set of applied what-if levers fully determine the limit
/// via the pure ``PrequalEngine`` — there is no hidden state.
@MainActor
@Observable
final class CreditStore {
    static let shared = CreditStore()

    private(set) var baseInputs = CreditProfileInputs(monthlyIncome: 0, monthlyDebt: 0, creditScore: 0)
    private(set) var obligations: [Obligation] = []
    private(set) var openedCredits: [OpenedCredit] = []

    /// Ids of the simulator levers the user has toggled on (§10.5 «что если…»).
    var appliedLevers: Set<String> = []

    private(set) var didLoad = false
    private var loadedProfileId: String?
    private var seq = 0

    private init() {}

    // MARK: - Demo seed data (nonisolated → usable from a View `init` for the suggested amount)

    /// Demo borrower's obligations: a salaried, mortgaged personal client whose ПДН is healthy-but-
    /// not-perfect, so every factor and lever in the explainable view reads as meaningful (§10.5).
    nonisolated static let demoObligations: [Obligation] = [
        Obligation(id: "ob_card", kind: .creditCard, lender: "Кредитка «Тинькофф»",
                   monthlyPayment: 12_000, balance: 138_000),
        Obligation(id: "ob_loan", kind: .consumerLoan, lender: "Потребкредит «Сбер»",
                   monthlyPayment: 15_000, balance: 312_000),
        Obligation(id: "ob_bnpl", kind: .bnpl, lender: "Рассрочка «Ромео»",
                   monthlyPayment: 4_000, balance: 16_000),
        Obligation(id: "ob_mortgage", kind: .mortgage, lender: "Ипотека «ДОМ.РФ»",
                   monthlyPayment: 38_000, balance: 4_120_000),
    ]

    /// Base inputs — `monthlyDebt` derives from the obligations (single source of truth).
    nonisolated static let demoInputs = CreditProfileInputs(
        monthlyIncome: 195_000,
        monthlyDebt: demoObligations.reduce(0) { $0 + $1.monthlyPayment },
        creditScore: 766)

    /// Ceiling the client may SELF-REQUEST in the application (§10.5) — «до 2 млн». The pre-approved
    /// amount (instant) is lower; the part above it is granted subject to verification, so the apply
    /// flow lets the user pick any amount up to this ceiling and labels what needs confirmation.
    nonisolated static let demoRequestCeiling: Double = 2_000_000

    /// Self-request ceiling for a product = demo ceiling, kept within the product's own max, and never
    /// below the pre-approved amount.
    nonisolated static func requestableLimit(for product: CreditProduct, preApproved: Double) -> Double {
        max(preApproved, min(product.maxAmount, demoRequestCeiling))
    }

    // MARK: - Load / seed (once per profile)

    func load(profileId: String) {
        let pid = profileId.isEmpty ? MockData.personalProfileId : profileId
        guard loadedProfileId != pid else { return }
        obligations = Self.demoObligations
        baseInputs = Self.demoInputs
        openedCredits = []
        appliedLevers = []
        loadedProfileId = pid
        didLoad = true
    }

    // MARK: - Simulator (§10.5)

    /// All available what-if levers: close each closable obligation, confirm extra income, clean history.
    var levers: [SimulatorLever] {
        var result: [SimulatorLever] = obligations
            .filter { $0.kind.isClosableLever }
            .map { ob in
                SimulatorLever(
                    id: "lv_close_\(ob.id)",
                    title: "Закрыть «\(ob.lender)»",
                    subtitle: "−\(CreditFormat.rub(ob.monthlyPayment))/мес нагрузки",
                    systemImage: ob.kind.systemImage,
                    effect: .closeObligation(id: ob.id, monthlyPayment: ob.monthlyPayment))
            }
        result.append(SimulatorLever(
            id: "lv_income",
            title: "Подтвердить доход 2-НДФЛ",
            subtitle: "+\(CreditFormat.rub(45_000))/мес к подтверждённому доходу",
            systemImage: "doc.text.fill",
            effect: .confirmIncome(extra: 45_000)))
        result.append(SimulatorLever(
            id: "lv_history",
            title: "Без просрочек 6 месяцев",
            subtitle: "скоринг +40 пунктов",
            systemImage: "checkmark.seal.fill",
            effect: .cleanHistory(scoreBoost: 40)))
        return result
    }

    /// Inputs after applying the currently-toggled levers — the basis for the simulated limit.
    var simulatedInputs: CreditProfileInputs { apply(levers.filter { appliedLevers.contains($0.id) }, to: baseInputs) }

    private func apply(_ active: [SimulatorLever], to inputs: CreditProfileInputs) -> CreditProfileInputs {
        var inp = inputs
        for lever in active {
            switch lever.effect {
            case .closeObligation(_, let pay): inp.monthlyDebt = max(0, inp.monthlyDebt - pay)
            case .confirmIncome(let extra):    inp.monthlyIncome += extra
            case .cleanHistory(let boost):     inp.creditScore += boost
            }
        }
        return inp
    }

    func toggleLever(_ id: String) {
        if appliedLevers.contains(id) { appliedLevers.remove(id) } else { appliedLevers.insert(id) }
    }

    func isApplied(_ id: String) -> Bool { appliedLevers.contains(id) }

    /// Exact Δ to the approved limit from toggling a single lever (with the other applied levers held).
    func delta(of lever: SimulatorLever, for product: CreditProduct) -> Double {
        let active = levers.filter { appliedLevers.contains($0.id) }
        let withoutThis = active.filter { $0.id != lever.id }
        let withThis = withoutThis + [lever]
        let base = PrequalEngine.approvedLimit(for: product, inputs: apply(withoutThis, to: baseInputs))
        let next = PrequalEngine.approvedLimit(for: product, inputs: apply(withThis, to: baseInputs))
        return next - base
    }

    // MARK: - Pre-qual results

    func approvedLimit(for product: CreditProduct, simulated: Bool = false) -> Double {
        PrequalEngine.approvedLimit(for: product, inputs: simulated ? simulatedInputs : baseInputs)
    }

    func personalRate(for product: CreditProduct, simulated: Bool = false) -> Double {
        PrequalEngine.rate(for: product, score: (simulated ? simulatedInputs : baseInputs).creditScore)
    }

    func factors(simulated: Bool = false) -> [DecisionFactor] {
        PrequalEngine.factors(simulated ? simulatedInputs : baseInputs)
    }

    func dti(simulated: Bool = false) -> Double {
        PrequalEngine.dti(simulated ? simulatedInputs : baseInputs)
    }

    /// Base (un-simulated) approved limit across the whole shelf — the витрина hero teaser.
    var heroLimit: Double { approvedLimit(for: CreditCatalog.primary) }

    // MARK: - Application (§10.5 оформление)

    /// Record a successfully-opened credit (after biometrics). Demo simulation.
    @discardableResult
    func open(product: CreditProduct, amount: Double, rate: Double, termMonths: Int) -> OpenedCredit {
        seq += 1
        let payment = LoanMath.monthlyPayment(principal: amount, annualRatePercent: rate, months: termMonths)
        let credit = OpenedCredit(
            id: "cr_open_\(seq)", productId: product.id, kind: product.kind,
            amount: amount, rate: rate, termMonths: termMonths, monthlyPayment: payment,
            openedAt: Date())
        openedCredits.insert(credit, at: 0)
        return credit
    }
}
