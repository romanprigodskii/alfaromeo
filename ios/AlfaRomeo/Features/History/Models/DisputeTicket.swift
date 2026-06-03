import Foundation

/// A dispute / support ticket opened from a transaction («Оспорить операцию», §9.4).
///
/// This is intentionally the **shared contract for «Обращения»** (§9.5 «Список → Обращения»): the
/// Чаты module will list and continue these same tickets once it lands. Until there's a second
/// consumer it lives here in the История module (no shared `Core/` type to widen yet) and is owned by
/// ``HistoryStore`` — when Чаты arrives, lift this struct + the ticket array into a shared store and
/// both modules read it. Kept free of any History-only dependency so the move is mechanical.
struct DisputeTicket: Identifiable, Hashable, Sendable {
    enum Status: String, Hashable, Sendable {
        case received      // обращение принято (initial)
        case inReview      // на рассмотрении
        case resolved      // решено

        var title: String {
            switch self {
            case .received: return "Обращение принято"
            case .inReview: return "На рассмотрении"
            case .resolved: return "Решено"
            }
        }
    }

    let id: String              // human case number, e.g. "DSP-24001"
    let txId: String            // disputed operation
    let counterparty: String?
    let categoryTitle: String
    let amount: Double
    let currency: String
    var status: Status
    let createdAt: Date
}
