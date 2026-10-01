import SwiftUI

/// A product on the кредитная витрина (§10.5 наличные / карта / рассрочка) as one row of the
/// «Продукты» grouped section: its pre-approved amount (or the product ceiling), the personalised
/// rate and key terms. Tapping opens the application.
struct CreditProductRow: View {
    let product: CreditProduct
    let approvedLimit: Double
    let rate: Double
    var onApply: () -> Void

    @Environment(\.theme) private var theme

    private var approved: Bool { approvedLimit > 0 }

    private var amountLine: String {
        approved ? "Предодобрено \(CreditFormat.rub(approvedLimit))"
                 : "\(product.kind.amountNoun) до \(CreditFormat.rub(product.maxAmount))"
    }

    private var rateValue: String {
        product.kind.isInterestFree ? CreditFormat.rate(0) : CreditFormat.rate(rate)
    }

    var body: some View {
        Button(action: onApply) {
            HStack(alignment: .top, spacing: ListRow.glyphSpacing) {
                GlyphCircle(systemImage: product.kind.systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        Text(product.name).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        Spacer(minLength: Spacing.sm)
                        Text(rateValue)
                            .font(BrandFont.bodyM).monospacedDigit()
                            .foregroundStyle(theme.textPrimary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Text(amountLine)
                        .font(BrandFont.subheadline).monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                    Text(product.highlights.joined(separator: ". ") + ".")
                        .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .multilineTextAlignment(.leading)
            }
            .padding(.vertical, Spacing.rowVertical)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
        .accessibilityElement(children: .combine)
        .accessibilityHint(approved ? "Оформить" : "Узнать условия")
    }
}
