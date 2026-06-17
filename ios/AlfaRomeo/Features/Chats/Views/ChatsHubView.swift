import SwiftUI

/// Чаты (§9.5): a messenger-style dialog list. The AI-поддержка (Claude) channel — the primary support
/// channel — is pinned on top, followed by the bank / operator / обращения / уведомления dialogs. Each
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
            SurfaceCard(padding: Spacing.md) {
                VStack(spacing: 0) {
                    dialog(title: "AI-поддержка",
                           preview: "Спросите что угодно — отвечу и подготовлю действие",
                           icon: "sparkles", gradient: true, online: true) {
                        router.push(CopilotRoute.chat(.standard))
                    }
                    rowDivider
                    dialog(title: "Чат с банком",
                           preview: "Счета, карты, продукты и тарифы",
                           icon: "building.columns", tint: theme.accent, online: true) {
                        router.push(CopilotRoute.chat(.bankChat))
                    }
                    rowDivider
                    dialog(title: "Чат с оператором",
                           preview: "Помогу и переключу на живого сотрудника",
                           icon: "headset", tint: theme.accent, online: true) {
                        router.push(CopilotRoute.chat(.operatorChat))
                    }
                    rowDivider
                    dialog(title: "Обращения",
                           preview: disputesPreview,
                           icon: "exclamationmark.bubble.fill", tint: theme.warning,
                           time: latestTicket.map { relative($0.createdAt) },
                           badge: history.tickets.count) {
                        router.push(ChatsRoute.disputes)
                    }
                    rowDivider
                    dialog(title: "Уведомления",
                           preview: notificationsPreview,
                           icon: "bell.badge.fill", tint: theme.accent,
                           time: latestNotification.map { relative($0.date) },
                           badge: notifications.unreadCount) {
                        router.push(ChatsRoute.notifications)
                    }
                }
            }
            .padding(Spacing.lg)
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

    private func dialog(title: String, preview: String, icon: String,
                        gradient: Bool = false, tint: Color? = nil, online: Bool = false,
                        time: String? = nil, badge: Int = 0,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                avatar(icon: icon, gradient: gradient, tint: tint ?? theme.accent, online: online)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary).lineLimit(1)
                    Text(preview)
                        .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                        .lineLimit(1).truncationMode(.tail)
                }
                Spacer(minLength: Spacing.sm)
                VStack(alignment: .trailing, spacing: 6) {
                    if online {
                        Text("онлайн")
                            .font(BrandFont.micro.weight(.semibold)).foregroundStyle(theme.success)
                    } else if let time {
                        Text(time).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    }
                    if badge > 0 { unreadBadge(badge) }
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func avatar(icon: String, gradient: Bool, tint: Color, online: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(gradient ? Color.white : tint)
                .frame(width: 52, height: 52)
                .background {
                    if gradient { Circle().fill(theme.cryptoGradient) }
                    else { Circle().fill(tint.opacity(0.14)) }
                }
            if online {
                Circle().fill(theme.success).frame(width: 13, height: 13)
                    .overlay(Circle().stroke(theme.surface, lineWidth: 2))
            }
        }
    }

    private func unreadBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(BrandFont.micro.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .frame(minWidth: 20)
            .background(theme.accent, in: Capsule())
    }

    private var rowDivider: some View {
        Divider().overlay(theme.border).padding(.leading, 52 + Spacing.md)
    }

    // MARK: - Live preview / time (read-only on the shared stores)

    private var latestTicket: DisputeTicket? {
        history.tickets.max { $0.createdAt < $1.createdAt }
    }
    private var latestNotification: AppNotification? {
        notifications.items.max { $0.date < $1.date }
    }
    private var disputesPreview: String {
        if let t = latestTicket { return "\(t.status.title) · \(t.counterparty ?? t.categoryTitle)" }
        return "Споры по операциям"
    }
    private var notificationsPreview: String {
        latestNotification?.title ?? "Платежи, безопасность, продукты"
    }
    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
