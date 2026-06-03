import SwiftUI

/// Navigation routes owned by the Кредиты hub (§10.5). Pushed onto the Главный section ``Router`` and
/// resolved by ``CreditView`` via its own `.navigationDestination(for:)`. The module is self-wiring
/// except for the single pending hub seam in Home — `case .credits: CreditView()` in
/// `HomeRoute.destination` — exactly like the Crypto/Savings hubs.
enum CreditRoute: Hashable {
    case prequal                       // explainable пре-квалификация + симулятор
    case apply(productId: String)      // оформление: сумма/срок → график → согласия → биометрия → статус

    @ViewBuilder var destination: some View {
        switch self {
        case .prequal:           PrequalView()
        case .apply(let id):     CreditApplyView(productId: id)
        }
    }
}
