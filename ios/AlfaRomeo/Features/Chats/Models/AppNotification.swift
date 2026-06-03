import Foundation

/// An inbox notification shown in Чаты → «Уведомления» (§9.5). Demo feed — there's no notifications
/// backend yet; read/unread state lives in ``NotificationsStore`` for the session. Named `App…` to
/// avoid colliding with Foundation's `Notification`.
struct AppNotification: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case security      // вход / подозрительная активность
        case payment       // перевод / зачисление / списание
        case product       // кэшбек / предложения / тариф
        case system        // продуктовые / регуляторные новости

        var icon: String {
            switch self {
            case .security: return "lock.shield.fill"
            case .payment:  return "creditcard.fill"
            case .product:  return "gift.fill"
            case .system:   return "bell.badge.fill"
            }
        }
    }

    let id: String
    let kind: Kind
    let title: String
    let body: String
    let date: Date
    var isRead: Bool
}
