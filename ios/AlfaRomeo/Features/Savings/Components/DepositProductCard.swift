import SwiftUI

/// A ruble-deposit product card for the hub (§10.6): ставка (tier-boosted), срок, капитализация /
/// пополнение / снятие, и честный бейдж «Застраховано АСВ».
struct DepositProductCard: View {
    let product: DepositProduct
    let apy: Double          // already tier-adjusted (§4) by the hub
    let isPremium: Bool      // top tier → boosted APY
    var onOpen: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                        Text(product.tagline).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                    Spacer(minLength: Spacing.sm)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(SavingsFormat.percent(apy))
                            .font(BrandFont.mono(22, weight: .semibold))
                            .foregroundStyle(theme.success)
                        Text("годовых").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        SavingsChip(text: "до \(product.termsMonths.max() ?? 0) мес", systemImage: "calendar")
                        if product.allowsCapitalization {
                            SavingsChip(text: "капитализация", systemImage: "arrow.triangle.2.circlepath")
                        }
                        if product.allowsTopUp { SavingsChip(text: "пополнение", systemImage: "plus") }
                        if product.allowsWithdrawal { SavingsChip(text: "снятие", systemImage: "arrow.down") }
                        SavingsChip(text: "от \(SavingsFormat.rub(product.minAmount))", systemImage: "rublesign")
                    }
                }

                HStack(spacing: Spacing.sm) {
                    SavingsChip(text: product.risk.badge, systemImage: product.risk.systemImage, tint: theme.success)
                    if isPremium { SavingsChip(text: "Premium APY", systemImage: "sparkles", tint: theme.accent) }
                    Spacer(minLength: 0)
                }

                SecondaryButton(title: "Открыть вклад", icon: "chevron.right") { onOpen() }
            }
        }
    }
}

#Preview {
    DepositProductCard(product: SavingsCatalog.depositProducts[1], apy: 17.2, isPremium: true) {}
        .padding()
        .environment(\.theme, .default)
}
