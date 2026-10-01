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
                    Text("Оптимизация налога")
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text(MoneyFormat.percent(-Double(tax.savingPercent)))
                        .font(BrandFont.headline).monospacedDigit()
                        .foregroundStyle(theme.success)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Сейчас: \(tax.current)").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    Text("Выгоднее: \(tax.suggested)").font(BrandFont.subheadline).foregroundStyle(theme.textPrimary)
                }
                .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text("Экономия около").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    Text("\(BizFormat.ruble(tax.savingRubPerYear)) в год")
                        .font(BrandFont.body(15, weight: .semibold)).monospacedDigit().foregroundStyle(theme.textPrimary)
                }

                Button(action: onAsk) {
                    Text("Спросить подробнее")
                        .font(BrandFont.body(15, weight: .medium))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.xxs)
            }
        }
    }
}
