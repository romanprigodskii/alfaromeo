import SwiftUI

/// Чаты → «Обращения» → деталь (§9.5): a status timeline for one dispute, the disputed-operation
/// summary, and one-tap entry to the AI / оператор. Reuses the shared ``DisputeTicket`` (the «оспорить»
/// contract) looked up from ``HistoryStore`` — no second ticket type.
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
                .padding(Spacing.lg)
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
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 64, height: 64)
                .background(theme.accent.opacity(0.16),
                            in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
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
        SurfaceCard(padding: Spacing.sm) {
            VStack(spacing: 0) {
                ListRow(icon: "number", title: "Номер обращения", value: ticket.id)
                divider
                ListRow(icon: "building.2", title: "Получатель", value: ticket.counterparty ?? ticket.categoryTitle)
                divider
                ListRow(icon: "rublesign.circle", title: "Сумма операции", value: DisputeFormat.amount(ticket))
                divider
                ListRow(icon: "calendar", title: "Создано", value: DisputeFormat.created(ticket))
                divider
                ListRow(icon: "doc.text", title: "ID операции", value: ticket.txId)
            }
        }
    }

    private func actions(_ ticket: DisputeTicket) -> some View {
        VStack(spacing: Spacing.sm) {
            SecondaryButton(title: "Спросить у AI", icon: "sparkles") {
                shell.showCopilot(.operation(
                    id: ticket.txId,
                    title: ticket.counterparty ?? ticket.categoryTitle,
                    amount: DisputeFormat.amount(ticket)))
            }
            SecondaryButton(title: "Позвать оператора", icon: "headset") {
                shell.showCopilot(.operatorChat)
            }
            Text("Среднее время ответа — до 24 часов. Если потребуется, эскалируем на живого оператора прямо в чате.")
                .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var notFound: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 40, weight: .light)).foregroundStyle(theme.textSecondary)
            Text("Обращение не найдено")
                .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Text("Возможно, оно относится к другому профилю.")
                .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.xxl)
    }

    private var divider: some View { Divider().overlay(theme.border) }
}
