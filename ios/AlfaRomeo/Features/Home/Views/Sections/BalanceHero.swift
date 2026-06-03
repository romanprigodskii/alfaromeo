import SwiftUI

/// Unified ₽-equivalent header (§10.2 «Единый ₽-эквивалент в шапке»). Folds fiat + live crypto, so it
/// ticks in real time as ``PriceSocket`` updates (§11.4).
struct BalanceHero: View {
    let dashboard: HomeDashboard
    let live: [String: Double]

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var total: Double { dashboard.unifiedTotalRub(live: live) }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Всего · ₽-эквивалент")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                AmountText(amount: total, size: 34)
                    .animation(reduceMotion ? nil : Motion.snappy, value: total)

                HStack(spacing: Spacing.xl) {
                    stat("Счета", dashboard.fiatRub)
                    if !dashboard.wallets.isEmpty {
                        stat("Крипта", dashboard.cryptoValueRub(live: live))
                    }
                }
            }
        }
    }

    private func stat(_ label: String, _ amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            AmountText(amount: amount, size: 16)
                .animation(reduceMotion ? nil : Motion.snappy, value: amount)
        }
    }
}
