import SwiftUI

/// Чаты (§9.5): the AI-поддержка (Claude) channel — the primary support channel — plus the bank /
/// operator / обращения / уведомления rows. All four rows are live:
/// • «Чат с банком» / «Чат с оператором» open the live ``CopilotChatView`` with the matching context
///   (the operator channel offers human escalation in text — no live operator is built, §10.9);
/// • «Обращения» lists the shared ``DisputeTicket``s opened via «Оспорить» in История (§9.4) — one
///   source of truth, no duplicate type;
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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("AI-поддержка, операторы и обращения (§9.5).")
                    .font(BrandFont.body())
                    .foregroundStyle(theme.textSecondary)

                Button { router.push(CopilotRoute.chat(.standard)) } label: {
                    aiChannel
                }
                .buttonStyle(PressableButtonStyle())

                SurfaceCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        channelRow("Чат с банком", "building.columns", "Счета, карты, продукты, тарифы") {
                            router.push(CopilotRoute.chat(.bankChat))
                        }
                        divider
                        channelRow("Чат с оператором", "headset", "С эскалацией на сотрудника") {
                            router.push(CopilotRoute.chat(.operatorChat))
                        }
                        divider
                        channelRow("Обращения", "doc.text", disputesSubtitle, badge: history.tickets.count) {
                            router.push(ChatsRoute.disputes)
                        }
                        divider
                        channelRow("Уведомления", "bell.badge", "Платежи, безопасность, продукты",
                                   badge: notifications.unreadCount) {
                            router.push(ChatsRoute.notifications)
                        }
                    }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .contentMargins(.bottom, 96, for: .scrollContent)
        .navigationDestination(for: CopilotRoute.self) { $0.destination }
        .navigationDestination(for: ChatsRoute.self) { $0.destination }
        // Hydrate История for the active profile so the «Обращения» count reflects opened tickets.
        // Idempotent for the same profile — won't wipe session tickets created via «Оспорить».
        .task(id: profileId) { await history.load(api: api, profileId: profileId) }
    }

    private var disputesSubtitle: String {
        history.tickets.isEmpty ? "Споры по операциям" : "Из «оспорить» в Истории"
    }

    private var aiChannel: some View {
        SurfaceCard {
            HStack(spacing: Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(theme.cryptoGradient, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI-поддержка (Claude)")
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Text("Стриминг, карточки-действий, эскалация")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func channelRow(_ title: String, _ icon: String, _ subtitle: String,
                            badge: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ListRow(icon: icon, title: title, subtitle: subtitle,
                    value: badge > 0 ? "\(badge)" : nil, showsChevron: true)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View { Divider().overlay(theme.border) }
}
