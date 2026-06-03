import Foundation

/// An existing debt obligation from the credit bureau (demo data). Its monthly payment feeds the
/// долговая-нагрузка (ПДН) factor, and — when closable — it becomes a simulator lever that frees
/// capacity (§10.5 «если закрыть карту X — лимит +Y»). Secured/long debts (ипотека, авто) are shown
/// but intentionally NOT offered as «close» levers — an honest simulator won't suggest it.
struct Obligation: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case creditCard, consumerLoan, autoLoan, mortgage, bnpl

        var title: String {
            switch self {
            case .creditCard:   return "Кредитная карта"
            case .consumerLoan: return "Потребкредит"
            case .autoLoan:     return "Автокредит"
            case .mortgage:     return "Ипотека"
            case .bnpl:         return "Рассрочка"
            }
        }
        var systemImage: String {
            switch self {
            case .creditCard:   return "creditcard"
            case .consumerLoan: return "banknote"
            case .autoLoan:     return "car"
            case .mortgage:     return "house"
            case .bnpl:         return "bag"
            }
        }
        /// Mortgage/auto are secured & long — the simulator won't suggest closing them.
        var isClosableLever: Bool {
            switch self {
            case .creditCard, .consumerLoan, .bnpl: return true
            case .autoLoan, .mortgage:              return false
            }
        }
    }

    let id: String
    let kind: Kind
    let lender: String
    let monthlyPayment: Double     // ₽/мес — the ПДН contribution
    let balance: Double            // остаток долга
}
