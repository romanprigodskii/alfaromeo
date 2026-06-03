import SwiftUI

/// Navigation routes owned by the Cards module (§6). Cards are surfaced from the home dashboard
/// (§9.1) and resolved in ``HomeView``'s stack, so the route + its destinations live with the module
/// that owns them. All cases resolve via the same `.navigationDestination(for: CardsRoute.self)` the
/// home stack already registers, so any Cards screen can `@Environment(Router.self)` and push deeper.
enum CardsRoute: Hashable {
    case list                       // CardsView — карты профиля (карусель, заказ)
    case detail(cardId: String)     // CardDetailView — управление картой (§6.3)
    case order                      // CardOrderView — заказ карты (§6.2)
    case tracking(orderId: String)  // CardDeliveryTrackingView — трекинг доставки пластика (§6.2)
}

extension CardsRoute {
    /// Destination for each route, owned by the Cards module.
    @ViewBuilder var destination: some View {
        switch self {
        case .list:                 CardsView()
        case .detail(let cardId):   CardDetailView(cardId: cardId)
        case .order:                CardOrderView()
        case .tracking(let orderId): CardDeliveryTrackingView(orderId: orderId)
        }
    }
}
