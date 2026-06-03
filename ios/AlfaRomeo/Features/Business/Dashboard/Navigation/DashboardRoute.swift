import SwiftUI

/// Navigation routes owned by the business **Дашборд** (§8.2, §9.9). Pushed onto the Дашборд tab's own
/// `NavigationStack` and resolved by ``BusinessDashboardView``. The only push is opening a «на подпись»
/// task: it reuses the **Команда** module's ``ApprovalDetailView`` against the shared ``TeamStore`` — the
/// *same* ``ApprovalRequest`` 2-of-N заявки, not a duplicate — so signing from the dashboard and from
/// the Команда tab act on one source of truth. Cross-tab jumps (открыть Счета / Команда / AI-бухгалтер)
/// are tab switches, not pushes, so they don't live here.
enum DashboardRoute: Hashable {
    case approval(approvalId: String)
}

extension DashboardRoute {
    @ViewBuilder var destination: some View {
        switch self {
        case .approval(let id): ApprovalDetailView(approvalId: id)
        }
    }
}
