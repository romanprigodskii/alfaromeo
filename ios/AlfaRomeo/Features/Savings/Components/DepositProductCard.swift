import SwiftUI

/// A ruble-deposit product row for the hub's «Вклады» ``GroupedSection`` (§10.6): name, minimum and
/// term range, the пополнение/снятие terms, and the tier-boosted rate. Tapping opens the wizard.
/// АСВ insurance is stated once in the section footer.
struct DepositProductCard: View {
    let product: DepositProduct
    let apy: Double          // already tier-adjusted (§4) by the hub
    let isPremium: Bool      // top tier → boosted APY (announced once in the hub header)
    var onOpen: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(BrandFont.bodyM)
                        .foregroundStyle(theme.textPrimary)
                    Text("От \(SavingsFormat.rub(product.minAmount)), \(SavingsFormat.months(product.termsMonths))")
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                    Text(product.tagline)
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(SavingsFormat.percent(apy))
                        .font(BrandFont.headline)
                        .monospacedDigit()
                        .foregroundStyle(theme.textPrimary)
                    Text("годовых")
                        .font(BrandFont.footnote)
                        .foregroundStyle(theme.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.vertical, Spacing.rowVertical)
            .frame(minHeight: Spacing.rowMinHeightTwoLine)
        }
        .buttonStyle(.row)
        .accessibilityHint("Открыть вклад")
    }
}

#Preview {
    GroupedSection("Вклады") {
        DepositProductCard(product: SavingsCatalog.depositProducts[0], apy: 12, isPremium: false) {}
        DepositProductCard(product: SavingsCatalog.depositProducts[1], apy: 17.2, isPremium: true) {}
    }
    .padding()
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
