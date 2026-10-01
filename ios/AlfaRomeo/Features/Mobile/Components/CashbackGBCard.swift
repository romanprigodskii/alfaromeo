import SwiftUI

/// Кэшбек гигабайтами (§7.1): «траты по карте → ГБ». A grouped section with the accrued GB, the
/// tier-linked monthly rate, and a «Зачислить в пакет» action row that credits the earned GB as bonus data.
struct CashbackGBCard: View {
    let cashback: MobileCashback
    var onCredit: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        GroupedSection("Кэшбек гигабайтами",
                       footer: "Покупки по карте возвращаются гигабайтами. Их можно зачислить в пакет или копить.") {
            ListRow(icon: "gift", title: "Накоплено", subtitle: cashback.perMonthLabel,
                    value: cashback.earnedLabel)

            if cashback.creditedGb > 0 {
                ListRow(icon: "checkmark", title: "Зачислено в пакет", value: cashback.creditedLabel)
            }

            Button(action: onCredit) {
                Text("Зачислить в пакет")
                    .font(BrandFont.bodyM)
                    .foregroundStyle(cashback.hasEarned ? theme.accent : theme.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.row)
            .disabled(!cashback.hasEarned)
        }
    }
}
