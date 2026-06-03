import Foundation

/// Mutable state of the credit-application wizard (§10.5 оформление). The flow clamps `amount` to the
/// pre-qualified limit (частичное одобрение) and gates submission on all three consents.
struct CreditDraft: Hashable {
    var amount: Double
    var termMonths: Int
    var consentBureau = false      // запрос кредитной истории в БКИ
    var consentData = false        // обработка персональных данных
    var consentTerms = false       // индивидуальные условия договора

    var allConsentsGiven: Bool { consentBureau && consentData && consentTerms }

    init(product: CreditProduct, suggestedAmount: Double) {
        self.amount = suggestedAmount
        self.termMonths = product.defaultTerm
    }
}

/// A credit opened in the demo flow (§10.5) — appears in «Мои кредиты» on the витрина. Module-local:
/// the app has no `Credit` contract yet, and every mutation here is a simulation.
struct OpenedCredit: Identifiable, Hashable {
    let id: String
    let productId: String
    let kind: CreditKind
    let amount: Double
    let rate: Double
    let termMonths: Int
    let monthlyPayment: Double
    let openedAt: Date
}
