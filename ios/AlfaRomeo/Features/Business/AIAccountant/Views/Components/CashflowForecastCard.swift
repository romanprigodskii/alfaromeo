import SwiftUI

/// Hero insight card (§8.2): the 90-day cash-flow forecast — current balance, the Swift Charts
/// projection, and the projected minimum. The chart's cash-gap marker pairs with ``CashGapAlertCard``.
struct CashflowForecastCard: View {
    let scenario: CashflowScenario

    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Прогноз денежного потока")
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Text("\(scenario.companyName), 90 дней")
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                }

                Cashflow90Chart(scenario: scenario)

                HStack(alignment: .firstTextBaseline) {
                    stat(title: "Сейчас", value: BizFormat.compactRuble(scenario.startBalance), tint: theme.textPrimary)
                    Spacer()
                    stat(title: "Мин. прогноз",
                         value: BizFormat.compactRuble(scenario.minBalance),
                         tint: scenario.minBalance < 0 ? theme.danger : theme.textPrimary)
                    Spacer()
                    stat(title: "Через 90 дн.", value: BizFormat.compactRuble(scenario.endBalance), tint: theme.textPrimary)
                }
            }
        }
    }

    private func stat(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            Text(value).font(BrandFont.body(15, weight: .semibold)).monospacedDigit().foregroundStyle(tint)
        }
    }
}
