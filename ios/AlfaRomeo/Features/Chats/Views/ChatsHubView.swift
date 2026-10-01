import SwiftUI

/// Чаты (§9.5): a messenger-style dialog list in one ``GroupedSection``. The AI-поддержка (Claude)
/// channel, the primary support channel, is pinned on top, followed by the bank / operator / обращения / уведомления dialogs. Each
/// row reads like a conversation entry: an avatar, the channel name, a last-message preview, presence or
/// time, and an unread badge. Routing is unchanged:
/// • «Чат с банком» / «Чат с оператором» open the live ``CopilotChatView`` with the matching context
///   (the operator channel offers human escalation in text — no live operator is built, §10.9);
/// • «Обращения» lists the shared ``DisputeTicket``s opened via «Оспорить» in История (§9.4);
/// • «Уведомления» opens the demo feed with read/unread state.
struct ChatsHubView: View {
    @Environment(Router.self) private var router
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var history = HistoryStore.shared
    @State private var notifications = NotificationsStore.shared

    private var profileId: String { session.activeProfile?.id ?? "" }

    var body: some View {
        ScrollView {
            GroupedSection {
                dialog(title: "AI-поддержка",
                       preview: "Ответит и подготовит действие",
                       icon: "text.bubble", online: true) {
                    router.push(CopilotRoute.chat(.standard))
                }
                dialog(title: "Чат с банком",
                       preview: "Счета, карты, продукты и тарифы",
                       icon: "building.columns", online: true) {
                    router.push(CopilotRoute.chat(.bankChat))
                }
                dialog(title: "Чат с оператором",
                       preview: "Переключит на сотрудника банка",
                       icon: "headset", online: true) {
                    router.push(CopilotRoute.chat(.operatorChat))
                }
                dialog(title: "Обращения",
                       preview: disputesPreview,
                       icon: "exclamationmark.bubble",
                       time: latestTicket.map { relative($0.createdAt) },
                       badge: history.tickets.count) {
                    router.push(ChatsRoute.disputes)
                }
                dialog(title: "Уведомления",
                       preview: notificationsPreview,
                       icon: "bell",
                       time: latestNotification.map { relative($0.date) },
                       badge: notifications.unreadCount) {
                    router.push(ChatsRoute.notifications)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
        }
        .background(theme.background.ignoresSafeArea())
        .contentMargins(.bottom, 96, for: .scrollContent)
        .navigationDestination(for: CopilotRoute.self) { $0.destination }
        .navigationDestination(for: ChatsRoute.self) { $0.destination }
        // Hydrate История for the active profile so the «Обращения» preview/count reflect opened tickets.
        // Idempotent for the same profile — won't wipe session tickets created via «Оспорить».
        .task(id: profileId) { await history.load(api: api, profileId: profileId) }
    }

    // MARK: - Dialog row

    private static let avatarSize: CGFloat = 44
    private static let avatarSpacing: CGFloat = 12

    /// A messenger-style row: monochrome avatar, channel name, one-line preview, presence or time,
    /// and an unread count.
    private func dialog(title: String, preview: String, icon: String,
                        online: Bool = false, time: String? = nil, badge: Int = 0,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Self.avatarSpacing) {
                avatar(icon: icon, online: online)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary).lineLimit(1)
                    Text(preview)
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                        .lineLimit(1).truncationMode(.tail)
                }
                Spacer(minLength: Spacing.sm)
                if time != nil || badge > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        if let time {
                            Text(time)
                                .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                                .monospacedDigit()
                        }
                        if badge > 0 { Badge(kind: .count(badge), tint: theme.accent) }
                    }
                    .fixedSize()
                }
            }
            .padding(.vertical, Spacing.rowVertical)
        }
        .buttonStyle(.row)
        .groupedRowTextInset(Self.avatarSize + Self.avatarSpacing)
    }

    /// Monochrome avatar; a small green dot marks a channel that answers right now (presence is state).
    private func avatar(icon: String, online: Bool) -> some View {
        GlyphCircle(systemImage: icon, size: Self.avatarSize)
            .overlay(alignment: .bottomTrailing) {
                if online {
                    Circle().fill(theme.success).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(theme.surface, lineWidth: 2))
                        .offset(x: 1, y: 1)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(online ? "онлайн" : "")
    }

    // MARK: - Live preview / time (read-only on the shared stores)

    private var latestTicket: DisputeTicket? {
        history.tickets.max { $0.createdAt < $1.createdAt }
    }
    private var latestNotification: AppNotification? {
        notifications.items.max { $0.date < $1.date }
    }
    private var disputesPreview: String {
        if let t = latestTicket { return "\(t.counterparty ?? t.categoryTitle) · \(t.status.title)" }
        return "Споры по операциям"
    }
    private var notificationsPreview: String {
        latestNotification?.title ?? "Платежи, безопасность, продукты"
    }
    private func relative(_ date: Date) -> String {
        // A ticket opened this minute reads «сейчас», not «через 0 сек.».
        if abs(date.timeIntervalSinceNow) < 60 { return "сейчас" }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
