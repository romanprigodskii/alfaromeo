import SwiftUI

/// One РКО account row (§8.2) inside a ``GroupedSection``: a currency glyph, the account title + masked
/// number, and the native balance with a «≈ … ₽» valuation line for non-₽ accounts.
struct AccountRow: View {
    let item: BusinessAccountItem

    @Environment(\.theme) private var theme

    /// The group header already names the kind, so non-₽ rows keep the title short and move the
    /// currency code next to the masked number («USD ·· 4340»).
    private var rowTitle: String {
        switch item.group {
        case .rubles:        return item.title
        case .multicurrency: return "Валютный счёт"
        case .treasury:      return "Трежери"
        }
    }

    private var rowSubtitle: String {
        item.group == .rubles ? item.maskedNumber : "\(item.currency.uppercased()) \(item.maskedNumber)"
    }

    var body: some View {
        HStack(spacing: Spacing.sm + 4) {
            GlyphCircle(currency: item.currency)

            VStack(alignment: .leading, spacing: 2) {
                Text(rowTitle)
                    .font(BrandFont.bodyM)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text(rowSubtitle)
                    .font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
            }

            Spacer(minLength: Spacing.sm)

            VStack(alignment: .trailing, spacing: 2) {
                AmountText(amount: item.balance,
                           currency: item.currency.uppercased() == "RUB" ? "₽" : item.currency.uppercased(),
                           size: 17)
                if item.showsRubEquivalent {
                    Text("≈ \(MoneyFormat.compact(item.rubValue))")
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.vertical, Spacing.rowVertical)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
        .contentShape(Rectangle())
        .groupedRowTextInset(48)
    }
}
