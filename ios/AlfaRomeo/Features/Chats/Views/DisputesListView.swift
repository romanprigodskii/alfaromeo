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
                    GroupedSection(footer: "Обращение создаётся из операции в «Истории» кнопкой «Оспорить». Здесь его статус и переписка.") {
                        ForEach(store.tickets, id: \.id) { ticket in
                            Button { router.push(ChatsRoute.disputeDetail(ticketId: ticket.id)) } label: {
                                row(ticket)
                            }
                            .buttonStyle(.row)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Обращения")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
        // Idempotent for the active profile — won't wipe session tickets (same-profile load short-circuits).
        .task(id: profileId) { await store.load(api: api, profileId: profileId) }
    }

    /// Text row: counterparty and amount, then the ticket number and its status pill.
    private func row(_ ticket: DisputeTicket) -> some View {
        HStack(spacing: Spacing.sm + 4) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text(ticket.counterparty ?? ticket.categoryTitle)
                        .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.sm)
                    Text(DisputeFormat.amount(ticket))
                        .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                        .fixedSize()
                }
                HStack(spacing: Spacing.sm) {
                    Text(ticket.id)
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.sm)
                    StatusPill(status: ticket.status.pill, text: ticket.status.title)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.textTertiary)
        }
        .padding(.vertical, Spacing.rowVertical)
    }

    private var empty: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.bubble")
                .font(.system(size: 40, weight: .light)).foregroundStyle(theme.textTertiary)
                .padding(.bottom, Spacing.xs)
            Text("Обращений пока нет")
                .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Text("Если с операцией что-то не так, откройте её в «Истории» и нажмите «Оспорить». Обращение появится здесь.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.xxl)
        .padding(.horizontal, Spacing.md)
    }
}
