import SwiftUI

/// Navigation routes owned by the business **Счета/РКО** section (§8.2, §9.9). Pushed onto the Счета
/// tab's `NavigationStack` and resolved by ``BusinessAccountsView`` via
/// `.navigationDestination(for: AccountsRoute.self)` — the self-contained one-stack pattern the
/// Acquiring/Team hubs use. The hub is the tab root; everything below is a push.
enum AccountsRoute: Hashable {
    case accountDetail(accountId: String) // карточка счёта: баланс, ₽-оценка, выписка
    case statements                       // выписка по операциям (вход/список + экспорт)
}

extension AccountsRoute {
    @ViewBuilder var destination: some View {
        switch self {
        case .accountDetail(let id): AccountDetailView(accountId: id)
        case .statements:            BusinessStatementsView()
        }
    }
}
