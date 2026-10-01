import SwiftUI

/// One pending/closed approval as a ``GroupedSection`` row (§8.2 «задачи на подпись»): supplier,
/// amount, purpose, status and the 2-of-N signature count. Used in the «на подпись» list, the
/// Команда hub and the Дашборд task block.
struct ApprovalRow: View {
    let item: ApprovalItem

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(item.draft.supplierName)
                    .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: Spacing.sm)
                AmountText(amount: item.draft.amount, currency: "₽", size: 17)
            }
            Text(item.draft.purpose)
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                .lineLimit(1)

            HStack(spacing: Spacing.sm) {
                statusText
                Spacer(minLength: Spacing.sm)
                Text(item.progressLabel)
                    .font(BrandFont.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
                    .layoutPriority(1)
            }
            .padding(.top, Spacing.xxs)
        }
        .padding(.vertical, Spacing.rowVertical)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var statusText: some View {
        if item.isComplete {
            status("Подписано, исполнено (симуляция)", theme.statusInk(.success))
        } else if item.isRejected {
            status("Отклонено", theme.statusInk(.danger))
        } else {
            status("Инициатор: \(item.draft.initiatorName)", theme.textSecondary)
        }
    }

    private func status(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(BrandFont.footnote)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}
