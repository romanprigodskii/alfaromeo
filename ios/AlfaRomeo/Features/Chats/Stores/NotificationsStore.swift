import Foundation
import Observation

/// Shared, in-memory уведомления state for Чаты → «Уведомления» (§9.5). Mirrors ``HistoryStore``:
/// a `@MainActor @Observable` singleton held via `@State` in the screens, so marking one read updates
/// the list *and* the unread badge on the Чаты hub live. Demo feed (no notifications backend yet);
/// state is process-lifetime.
@MainActor
@Observable
final class NotificationsStore {
    static let shared = NotificationsStore()

    private(set) var items: [AppNotification] = NotificationsStore.seed()

    var unreadCount: Int { items.lazy.filter { !$0.isRead }.count }

    private init() {}

    func markRead(_ id: String) {
        guard let i = items.firstIndex(where: { $0.id == id }), !items[i].isRead else { return }
        items[i].isRead = true
    }

    func markAllRead() {
        for i in items.indices where !items[i].isRead { items[i].isRead = true }
    }

    /// Demo feed, newest-first. Relative offsets are anchored once at first access.
    private static func seed() -> [AppNotification] {
        let now = Date()
        func ago(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }
        return [
            AppNotification(id: "n1", kind: .payment, title: "Платёж выполнен",
                            body: "Перевод 12 400 ₽ на карту ··4921 прошёл успешно.",
                            date: ago(1), isRead: false),
            AppNotification(id: "n2", kind: .security, title: "Новый вход в приложение",
                            body: "Вход с нового устройства iPhone 16 Pro. Если это не вы — заморозьте доступ в «Безопасности».",
                            date: ago(5), isRead: false),
            AppNotification(id: "n3", kind: .product, title: "Кэшбек за май начислен",
                            body: "Начислено 1 830 ₽. Категории на июнь можно поменять в «Выгоде».",
                            date: ago(26), isRead: false),
            AppNotification(id: "n4", kind: .system, title: "Цифровой рубль",
                            body: "Кошелёк и универсальный QR уже доступны в разделе «Оплата».",
                            date: ago(50), isRead: true),
            AppNotification(id: "n5", kind: .payment, title: "Зачисление зарплаты",
                            body: "Поступление 95 000 ₽. Отложить часть на накопительный счёт?",
                            date: ago(74), isRead: true),
        ]
    }
}
