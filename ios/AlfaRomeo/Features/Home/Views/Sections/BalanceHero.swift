import SwiftUI

/// Единый ₽-эквивалент в шапке (§10.2). Folds fiat + live crypto, so it ticks in real time as
/// ``LivePriceService`` updates (§11.4); currency accounts are valued at курс ЦБ. Hero style per
/// DESIGN §6: integer at 40, kopecks smaller in secondary ink. Sits on the background, no card.
struct BalanceHero: View {
    let dashboard: HomeDashboard
    let live: [String: Double]

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var total: Double { dashboard.unifiedTotalRub(live: live) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Всего в рублях")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            AmountText(amount: total, size: 40, splitsKopecks: true)
                .animation(reduceMotion ? nil : Motion.snappy, value: total)

            HStack(spacing: Spacing.lg) {
                stat("Счета", dashboard.fiatRub)
                if !dashboard.wallets.isEmpty {
                    stat("Крипта", dashboard.cryptoValueRub(live: live))
                }
            }
            .padding(.top, Spacing.xxs)

            if dashboard.hasForeignFiat {
                Text("Валюта в ₽ · \(FXRateService.shared.label)")
                    .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ label: String, _ amount: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs + 2) {
            Text(label).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            AmountText(amount: amount, size: 15)
                .animation(reduceMotion ? nil : Motion.snappy, value: amount)
        }
    }
}
