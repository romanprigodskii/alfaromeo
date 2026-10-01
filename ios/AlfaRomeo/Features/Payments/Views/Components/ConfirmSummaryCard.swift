import SwiftUI

/// The «Подтверждение» summary (§9.2): получатель, крупная сумма, комиссия, ₽-эквивалент (для
/// крипты, по мок-курсу), счёт-источник и итог к списанию. Pure presentation — the flow passes
/// already-computed values.
struct ConfirmSummaryCard: View {
    let recipient: Recipient
    let amount: Double
    let amountSymbol: String
    let fee: Double
    var feeLabel: String = "Комиссия"
    let rubEquivalent: Double?       // crypto only
    let sourceTitle: String
    let sourceSubtitle: String
    let totalText: String?           // fiat total (amount + fee); nil for crypto

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Spacing.lg) {
            recipientHeader

            VStack(spacing: Spacing.xs) {
                AmountText(amount: amount, currency: amountSymbol, size: 40, splitsKopecks: true)
                if let rubEquivalent {
                    Text("≈ \(MoneyFormat.fiat(rubEquivalent)) по курсу")
                        .font(BrandFont.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)

            GroupedSection {
                detailRow(title: "Счёт списания", value: sourceTitle, sub: sourceSubtitle)
                detailRow(title: feeLabel, value: fee == 0 ? "Без комиссии" : MoneyFormat.fiat(fee))
                if let totalText {
                    detailRow(title: "Итого к списанию", value: totalText, emphasized: true)
                }
            }
        }
    }

    private var recipientHeader: some View {
        HStack(spacing: ListRow.glyphSpacing) {
            GlyphCircle(systemImage: recipient.icon, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(recipient.name).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text(recipient.detail).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
            }
            Spacer(minLength: Spacing.sm)
            if let bank = recipient.bank {
                Badge(kind: .text(bank))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(title: String, value: String,
                           sub: String? = nil, emphasized: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(title).font(BrandFont.bodyM).foregroundStyle(theme.textSecondary)
            Spacer(minLength: Spacing.sm)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(emphasized ? BrandFont.headline : BrandFont.bodyM)
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                if let sub {
                    Text(sub).font(BrandFont.subheadline).monospacedDigit().foregroundStyle(theme.textSecondary)
                }
            }
            .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Spacing.sm + 4)
        .frame(minHeight: Spacing.rowMinHeight)
    }
}

#Preview {
    ScrollView {
        ConfirmSummaryCard(
            recipient: Recipient(name: "Иван Петров", detail: "+7 916 200-11-22", icon: "person.fill", bank: "Альфа-Ромео"),
            amount: 5000, amountSymbol: "₽", fee: 0, rubEquivalent: nil,
            sourceTitle: "Текущий счёт", sourceSubtitle: "·· 4921 · RUB", totalText: MoneyFormat.fiat(5000)
        )
        .padding(Spacing.screen)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
