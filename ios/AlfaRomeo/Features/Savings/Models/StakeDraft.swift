import Foundation

/// Wizard state for crypto staking: актив → сумма → срок lock → раскрытие риска (обяз. чекбокс) →
/// подтверждение (§10.6). Amount is held in **asset units**; the ₽ estimate is computed live from the
/// price in ``SavingsStore``.
struct StakeDraft: Equatable {
    let product: StakeProduct
    var amountUnits: Double = 0
    var lockDays: Int
    var riskAccepted: Bool = false

    init(product: StakeProduct) {
        self.product = product
        self.lockDays = product.defaultLock
    }

    var meetsMinimum: Bool { amountUnits >= product.minUnits }

    /// Projected yield in asset units over a year at the given APY (informational).
    func projectedYearlyUnits(apy: Double) -> Double { amountUnits * (apy / 100) }
}
