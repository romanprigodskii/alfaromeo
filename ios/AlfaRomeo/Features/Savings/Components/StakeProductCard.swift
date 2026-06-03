import SwiftUI

/// A crypto-staking product card for the hub (§10.6): актив, APY (tier-boosted), lock, уровень риска,
/// и live ₽-цена за единицу. The cold crypto gradient visually separates it from fiat deposits (§13.1).
struct StakeProductCard: View {
    let product: StakeProduct
    let apy: Double            // already tier-adjusted (§4)
    let isPremium: Bool
    let unitPriceRub: Double   // live ₽ per 1 unit (from ``SavingsStore``)
    var onStake: () -> Void

    @Environment(\.theme) private var theme

    private var riskTint: Color {
        switch product.riskLevel {
        case .low:    return theme.success
        case .medium: return theme.warning
        case .high:   return theme.danger
        }
    }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top) {
                    HStack(spacing: Spacing.sm) {
                        assetGlyph
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                            Text("1 \(product.asset) ≈ \(SavingsFormat.rub(unitPriceRub))")
                                .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                                .contentTransition(.numericText())
                        }
                    }
                    Spacer(minLength: Spacing.sm)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(SavingsFormat.percent(apy))
                            .font(BrandFont.mono(22, weight: .semibold))
                            .foregroundStyle(theme.accentCrypto.first ?? theme.accent)
                        Text("APY").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        SavingsChip(text: product.riskLevel.label, systemImage: "waveform.path.ecg", tint: riskTint)
                        SavingsChip(text: lockLabel, systemImage: "lock")
                        if isPremium { SavingsChip(text: "Premium APY", systemImage: "sparkles", tint: theme.accent) }
                    }
                }

                HStack(spacing: Spacing.sm) {
                    SavingsChip(text: product.risk.badge, systemImage: product.risk.systemImage, tint: theme.warning)
                    Spacer(minLength: 0)
                }

                SecondaryButton(title: "Застейкать", icon: "chevron.right") { onStake() }
            }
        }
    }

    private var lockLabel: String {
        product.lockOptionsDays.contains(0) ? "гибкий lock" : "lock от \(product.lockOptionsDays.min() ?? 0) дн"
    }

    private var assetGlyph: some View {
        ZStack {
            Circle().fill(theme.cryptoGradient).frame(width: 38, height: 38)
            Text(String(product.asset.prefix(1)))
                .font(BrandFont.mono(16, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    StakeProductCard(product: SavingsCatalog.stakeProducts[1], apy: 6.2, isPremium: true,
                     unitPriceRub: 318_000) {}
        .padding()
        .environment(\.theme, .default)
}
