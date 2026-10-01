import SwiftUI

/// UI-only presentation helpers over the shared ``DisputeTicket`` (§9.5). Kept in Чаты so the
/// История-owned model stays UI-free. This only maps it to the design-system pill and a formatted
/// amount; it does **not** redefine the ticket (единый контракт).
extension DisputeTicket.Status {
    /// Maps the ticket lifecycle to a ``StatusPill`` style.
    var pill: StatusPill.Status {
        switch self {
        case .received: return .pending
        case .inReview: return .processing
        case .resolved: return .success
        }
    }
}

enum DisputeFormat {
    /// The disputed operation's amount through ``MoneyFormat`` (e.g. "1 990 ₽", "12,50 $").
    static func amount(_ ticket: DisputeTicket) -> String {
        MoneyFormat.fiat(abs(ticket.amount), currency: ticket.currency)
    }

    static func created(_ ticket: DisputeTicket) -> String {
        dateFormatter.string(from: ticket.createdAt)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()
}
