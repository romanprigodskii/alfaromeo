import SwiftUI

/// Navigation routes owned by the «Приумножить» hub (§10.6). Pushed onto the Главный section
/// ``Router`` and resolved by ``SavingsHubView`` via its own `.navigationDestination(for:)` — so the
/// whole module wires itself in with a single one-line change in `HomeRoute.deposits` (the hub entry).
enum SavingsRoute: Hashable {
    case openDeposit(productId: String)
    case stake(productId: String)
    case detail(depositId: String)
    case newGoal

    @ViewBuilder var destination: some View {
        switch self {
        case .openDeposit(let id): OpenDepositView(productId: id)
        case .stake(let id):       StakeFlowView(productId: id)
        case .detail(let id):      SavingsDetailView(depositId: id)
        case .newGoal:             NewGoalView()
        }
    }
}
