import SwiftUI

/// A crypto-staking product row for the hub's «Стейкинг» ``GroupedSection`` (§10.6): coin logo, live
/// ₽ price per unit, risk level and lock, and the tier-boosted APY. Tapping opens the stake wizard.
/// The "not insured" disclosure is stated once in the section footer.
struct StakeProductCard: View {
    let product: StakeProduct
    let apy: Double            // already tier-adjusted (§4)
    let isPremium: Bool        // announced once in the hub header
    let unitPriceRub: Double   // live ₽ per 1 unit (from ``SavingsStore``)
    var onStake: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onStake) {
            HStack(alignment: .center, spacing: Spacing.sm + 4) {
                CoinLogo(symbol: product.asset, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(BrandFont.bodyM)
                        .foregroundStyle(theme.textPrimary)
                    Text("1 \(product.asset) ≈ \(SavingsFormat.rub(unitPriceRub))")
                        .font(BrandFont.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                        .contentTransition(.numericText())
                        .animation(Motion.snappy, value: unitPriceRub)
                    Text("\(product.riskLevel.label), \(lockLabel)")
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(SavingsFormat.percent(apy))
                        .font(BrandFont.headline)
                        .monospacedDigit()
                        .foregroundStyle(theme.textPrimary)
                    Text("APY")
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
        .groupedRowTextInset(48)
        .accessibilityHint("Застейкать")
    }

    private var lockLabel: String {
        product.lockOptionsDays.contains(0)
            ? "гибкий lock"
            : "lock от \(product.lockOptionsDays.min() ?? 0)\(MoneyFormat.nbsp)дн"
    }
}

#Preview {
    GroupedSection("Стейкинг") {
        StakeProductCard(product: SavingsCatalog.stakeProducts[0], apy: 9.5, isPremium: false,
                         unitPriceRub: 92) {}
        StakeProductCard(product: SavingsCatalog.stakeProducts[1], apy: 6.2, isPremium: true,
                         unitPriceRub: 318_000) {}
    }
    .padding()
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
