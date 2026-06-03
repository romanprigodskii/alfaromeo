import Foundation

/// Domain models for the AI-бухгалтер's cash-flow insight cards (§8.2).
///
/// These describe ONE deterministic mock scenario (built by ``BusinessCashflowMock``) that is the iOS
/// mirror of the backend `BusinessCashflow` context digest (`ai.context.ts`). Because both sides tell
/// the same story — current balance, the cash gap, the tax saving, the expense split — the live Claude
/// chat and these on-screen cards never contradict each other in the demo.

/// One day on the 90-day projection: the projected end-of-day operating-account balance, in ₽.
struct CashflowPoint: Identifiable, Hashable, Sendable {
    let day: Int        // 0…90, days from today
    let date: Date
    let balance: Double
    var id: Int { day }
}

/// A scheduled cash event driving the projection (signed ₽: inflow +, outflow −).
struct CashflowEvent: Identifiable, Hashable, Sendable {
    let day: Int
    let date: Date
    let amount: Double
    let label: String
    var id: String { "\(day)·\(label)" }
    var isInflow: Bool { amount >= 0 }
}

/// The detected cash gap (§8.2): the projection's deepest negative point, expressed as a deficit
/// amount + the date/horizon it occurs. `nil` when the projection never goes negative.
struct CashGap: Hashable, Sendable {
    /// Magnitude of the deficit, a positive ₽ figure (the projected balance is `-amount`).
    let amount: Double
    let date: Date
    let inDays: Int
}

/// Tax-regime optimization advice (§8.2): current simplified-tax regime + a cheaper alternative.
struct TaxOptimization: Hashable, Sendable {
    let current: String
    let suggested: String
    let savingPercent: Int
    let savingRubPerYear: Double
}

/// One auto-classified monthly expense category (§8.2).
struct ExpenseCategory: Identifiable, Hashable, Sendable {
    let label: String
    let sharePercent: Int
    let amount: Double
    var id: String { label }
}

/// The full mock cash-flow scenario the AI-accountant renders + the live chat is grounded in (§8.2).
struct CashflowScenario: Hashable, Sendable {
    let companyName: String
    let startBalance: Double
    let points: [CashflowPoint]
    let events: [CashflowEvent]
    let gap: CashGap?
    let tax: TaxOptimization
    let expenses: [ExpenseCategory]
    let unpaidInvoicesCount: Int
    let unpaidInvoicesTotal: Double
    let classifiedOpsCount: Int
    let needsReviewCount: Int

    var minBalance: Double { points.map(\.balance).min() ?? startBalance }
    var maxBalance: Double { points.map(\.balance).max() ?? startBalance }
    var endBalance: Double { points.last?.balance ?? startBalance }
    var expenseTotal: Double { expenses.reduce(0) { $0 + $1.amount } }
}
