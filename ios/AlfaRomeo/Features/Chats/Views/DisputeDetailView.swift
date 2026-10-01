import SwiftUI

/// Чаты → «Обращения» → деталь (§9.5): a status timeline for one dispute, the disputed-operation
/// summary, and one-tap entry to the AI / оператор. Reuses the shared ``DisputeTicket`` (the «оспорить»
/// contract) looked up from ``HistoryStore``, no second ticket type.
struct DisputeDetailView: View {
    let ticketId: String

    @Environment(ShellState.self) private var shell
    @Environment(\.theme) private var theme

    @State private var store = HistoryStore.shared

    private var ticket: DisputeTicket? { store.tickets.first { $0.id == ticketId } }

    var body: some View {
        ScrollView {
            if let ticket {
                VStack(spacing: Spacing.lg) {
                    header(ticket)
                    timeline(ticket)
                    detailsCard(ticket)
                    actions(ticket)
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.md)
            } else {
                notFound
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Обращение")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
    }

    // MARK: Sections

    private func header(_ ticket: DisputeTicket) -> some View {
        VStack(spacing: Spacing.sm) {
            GlyphCircle(systemImage: "exclamationmark.bubble", size: 56)
            Text(ticket.status.title)
                .font(BrandFont.title).foregroundStyle(theme.textPrimary)
            StatusPill(status: ticket.status.pill, text: ticket.id)
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.sm)
    }

    /// Three-step lifecycle, the current step highlighted (§13.1 honest status).
    private func timeline(_ ticket: DisputeTicket) -> some View {
        let steps: [DisputeTicket.Status] = [.received, .inReview, .resolved]
        let current = steps.firstIndex(of: ticket.status) ?? 0
        return SurfaceCard {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: Spacing.md) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(index <= current ? theme.accent : theme.border)
                                .frame(width: 12, height: 12)
                            if index < steps.count - 1 {
                                Rectangle()
                                    .fill(index < current ? theme.accent : theme.border)
                                    .frame(width: 2, height: 26)
                            }
                        }
                        .padding(.top, 3)
                        Text(step.title)
                            .font(BrandFont.callout.weight(index == current ? .semibold : .regular))
                            .foregroundStyle(index <= current ? theme.textPrimary : theme.textSecondary)
                            .padding(.bottom, index < steps.count - 1 ? Spacing.md : 0)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func detailsCard(_ ticket: DisputeTicket) -> some View {
        GroupedSection {
            ListRow(title: "Номер обращения", value: ticket.id)
            ListRow(title: "Получатель", value: ticket.counterparty ?? ticket.categoryTitle)
            ListRow(title: "Сумма операции", value: DisputeFormat.amount(ticket))
            ListRow(title: "Создано", value: DisputeFormat.created(ticket))
            ListRow(title: "ID операции", value: ticket.txId)
        }
    }

    private func actions(_ ticket: DisputeTicket) -> some View {
        VStack(spacing: Spacing.sm) {
            SecondaryButton(title: "Спросить у AI") {
                shell.showCopilot(.operation(
                    id: ticket.txId,
                    title: ticket.counterparty ?? ticket.categoryTitle,
                    amount: DisputeFormat.amount(ticket)))
            }
            SecondaryButton(title: "Позвать оператора") {
                shell.showCopilot(.operatorChat)
            }
            Text("Среднее время ответа до 24 часов. Если потребуется, подключим оператора прямо в чате.")
                .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var notFound: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 40, weight: .light)).foregroundStyle(theme.textTertiary)
            Text("Обращение не найдено")
                .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Text("Возможно, оно относится к другому профилю.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.xxl)
    }
}
