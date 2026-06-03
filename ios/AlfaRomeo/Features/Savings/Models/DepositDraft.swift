import Foundation

/// Wizard state for opening a ruble deposit: сумма → срок → опции (капитализация/пополнение) →
/// подтверждение (§10.6). One mutable instance per ``OpenDepositView`` session.
struct DepositDraft: Equatable {
    let product: DepositProduct
    var amount: Double = 0
    var termMonths: Int
    var capitalize: Bool
    var topUp: Bool

    init(product: DepositProduct) {
        self.product = product
        self.termMonths = product.defaultTerm
        self.capitalize = product.allowsCapitalization
        self.topUp = product.allowsTopUp
    }

    var meetsMinimum: Bool { amount >= product.minAmount }

    /// Projected interest over the term (simple demo math; capitalization nudges it up a touch).
    func projectedInterest(apy: Double) -> Double {
        let years = Double(termMonths) / 12.0
        let simple = amount * (apy / 100) * years
        return capitalize ? simple * 1.03 : simple
    }
}
