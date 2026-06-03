import SwiftUI

/// Summary card for one pending/closed approval (§8.2 «задачи на подпись»): supplier, amount,
/// initiator, and a 2-of-N progress strip. Used in the «на подпись» list and the hub task block.
struct ApprovalCard: View {
    let item: ApprovalItem

    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceCard(padding: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.draft.supplierName)
                            .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                        Text(item.draft.purpose)
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: Spacing.sm)
                    AmountText(amount: item.draft.amount, currency: "₽", size: 18)
                }

                statusStrip

                HStack(spacing: Spacing.sm) {
                    ProgressBar(value: item.progress, height: 6)
                    Text(item.progressLabel)
                        .font(BrandFont.micro.weight(.medium))
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                        .layoutPriority(1)
                }
            }
        }
    }

    @ViewBuilder private var statusStrip: some View {
        if item.isComplete {
            label("Подписано · исполнено (симуляция)", "checkmark.seal.fill",
                  theme.isDark ? theme.success : BrandColors.successInkLight)
        } else if item.isRejected {
            label("Отклонено", "xmark.seal.fill", theme.isDark ? theme.danger : BrandColors.dangerInkLight)
        } else {
            label("Ждёт второй подписи · от \(item.draft.initiatorName)", "clock.badge.exclamationmark",
                  theme.accent)
        }
    }

    private func label(_ text: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(BrandFont.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(color)
    }
}
