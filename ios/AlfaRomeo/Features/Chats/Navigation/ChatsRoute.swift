import SwiftUI

/// Routes owned by the Чаты section (§9.5) for the non-AI channels — обращения (список + деталь) и
/// уведомления. Pushed onto the section ``Router`` and resolved by ``ChatsHubView`` alongside
/// ``CopilotRoute`` (which serves the AI / банк / оператор channels).
///
/// «Обращения» reuse the **shared** ``DisputeTicket`` from the История module — there is no second
/// ticket type (§9.5 «единый источник», как с ЦФА): the list reads `HistoryStore.shared.tickets`,
/// populated by «Оспорить операцию» in История (§9.4).
enum ChatsRoute: Hashable {
    case disputes                          // Обращения — список тикетов из «оспорить»
    case disputeDetail(ticketId: String)   // деталь обращения со статусом
    case notifications                     // Уведомления — лента (прочитано/непрочитано)
}

extension ChatsRoute {
    @ViewBuilder var destination: some View {
        switch self {
        case .disputes:
            DisputesListView()
        case .disputeDetail(let ticketId):
            DisputeDetailView(ticketId: ticketId)
        case .notifications:
            NotificationsListView()
        }
    }
}
