import SwiftUI

/// Navigation routes owned by the «Команда и роли» section (§8.2, §9.9). Pushed onto the business
/// **Команда** tab's `NavigationStack` and resolved by ``TeamHubView`` via
/// `.navigationDestination(for: TeamRoute.self)` — the self-contained one-stack pattern the
/// Crypto/Mobile hubs use. The hub is the tab root; everything below is a push.
enum TeamRoute: Hashable {
    case members                        // полный список сотрудников
    case memberDetail(memberId: String) // карточка сотрудника: роль, права, карты
    case addMember                      // добавить сотрудника (мок-инвайт)
    case roles                          // матрица роли × права + политика подписей
    case corpCards                      // корп-карты на сотрудников
    case corpCardDetail(cardId: String) // лимиты, заморозка
    case issueCard(memberId: String?)   // выпуск карты сотруднику
    case approvals                      // «на подпись» — список 2-of-N
    case approvalDetail(approvalId: String) // подпись биометрией → исполнение
    case paySupplier                    // сценарий «заплатить поставщику»
}

extension TeamRoute {
    @ViewBuilder var destination: some View {
        switch self {
        case .members:                       TeamMembersView()
        case .memberDetail(let id):          MemberDetailView(memberId: id)
        case .addMember:                     AddMemberView()
        case .roles:                         RolesMatrixView()
        case .corpCards:                     CorporateCardsView()
        case .corpCardDetail(let id):        CorporateCardDetailView(cardId: id)
        case .issueCard(let memberId):       IssueCorpCardView(presetMemberId: memberId)
        case .approvals:                     ApprovalsListView()
        case .approvalDetail(let id):        ApprovalDetailView(approvalId: id)
        case .paySupplier:                   SupplierPaymentView()
        }
    }
}
