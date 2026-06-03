import SwiftUI

/// Tax-optimization insight (§8.2): current simplified-tax regime → a cheaper alternative, with the
/// estimated saving in % and ₽/year. «Подробнее» asks Claude to walk through the switch.
struct TaxOptimizationCard: View {
    let tax: TaxOptimization
    var onAsk: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "percent")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(theme.cryptoGradient, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    Text("Оптимизация налога")
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text("−\(tax.savingPercent)%")
                        .font(BrandFont.headline)
                        .foregroundStyle(theme.success)
                }

                HStack(spacing: Spacing.xs) {
                    Text(tax.current).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold)).foregroundStyle(theme.textSecondary)
                    Text(tax.suggested).font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.textPrimary)
                }
                .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text("Экономия ≈").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    Text("\(BizFormat.ruble(tax.savingRubPerYear)) / год")
                        .font(BrandFont.mono(15, weight: .semibold)).foregroundStyle(theme.textPrimary)
                }

                Button(action: onAsk) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "sparkles").font(.system(size: 12, weight: .bold))
                        Text("Подробнее у AI-бухгалтера").font(BrandFont.caption.weight(.semibold))
                    }
                    .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.xxs)
            }
        }
    }
}
