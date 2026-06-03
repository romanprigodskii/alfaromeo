import SwiftUI

/// Чаты → «Обращения» (§9.5): the list of disputes opened from «Оспорить операцию» in История (§9.4).
/// Reads the **shared** ``DisputeTicket`` source (`HistoryStore.shared.tickets`) — one source of truth,
/// no duplicate ticket type. Tap a ticket → ``DisputeDetailView`` with its status.
struct DisputesListView: View {
    @Environment(Router.self) private var router
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var store = HistoryStore.shared

    private var profileId: String { session.activeProfile?.id ?? "" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if store.tickets.isEmpty {
                    empty
                } else {
                    Text("Открываются из операции в «Истории» → «Оспорить». Здесь — их статус и переписка.")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    SurfaceCard(padding: Spacing.sm) {
                        VStack(spacing: 0) {
                            ForEach(Array(store.tickets.enumerated()), id: \.element.id) { index, ticket in
                                Button { router.push(ChatsRoute.disputeDetail(ticketId: ticket.id)) } label: {
                                    row(ticket)
                                }
                                .buttonStyle(.plain)
                                if index < store.tickets.count - 1 { Divider().overlay(theme.border) }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Обращения")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
        // Idempotent for the active profile — won't wipe session tickets (same-profile load short-circuits).
        .task(id: profileId) { await store.load(api: api, profileId: profileId) }
    }

    private func row(_ ticket: DisputeTicket) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 36, height: 36)
                .background(theme.accent.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.counterparty ?? ticket.categoryTitle)
                    .font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                Text("\(ticket.id) · \(DisputeFormat.amount(ticket))")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            StatusPill(status: ticket.status.pill, text: ticket.status.title)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.textSecondary)
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
    }

    private var empty: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.bubble")
                .font(.system(size: 40, weight: .light)).foregroundStyle(theme.textSecondary)
            Text("Обращений пока нет")
                .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Text("Если с операцией что-то не так — откройте её в «Истории» и нажмите «Оспорить». Обращение появится здесь.")
                .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.xxl)
    }
}
