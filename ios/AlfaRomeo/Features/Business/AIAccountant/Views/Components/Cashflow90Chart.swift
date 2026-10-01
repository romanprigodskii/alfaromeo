import SwiftUI
import Charts

/// The 90-day cash-flow projection (§8.2) on Swift Charts: a filled balance curve, the zero baseline,
/// and, when the projection dips negative, a danger marker at the cash gap (the deepest point). The
/// area hangs BELOW the dashed zero line through the gap, so the liquidity shortfall reads at a glance.
struct Cashflow90Chart: View {
    let scenario: CashflowScenario

    @Environment(\.theme) private var theme

    var body: some View {
        Chart {
            // Filled balance area, explicitly anchored to 0 so the negative stretch hangs below the line.
            ForEach(scenario.points) { p in
                AreaMark(
                    x: .value("Дата", p.date),
                    yStart: .value("Ноль", 0),
                    yEnd: .value("Остаток", p.balance)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(areaFill)
            }

            ForEach(scenario.points) { p in
                LineMark(x: .value("Дата", p.date), y: .value("Остаток", p.balance))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(theme.textPrimary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // Zero baseline — the solvency line.
            RuleMark(y: .value("Ноль", 0))
                .foregroundStyle(theme.textSecondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            // Cash gap (§8.2) — the deepest negative point, called out in danger.
            if let gap = scenario.gap {
                RuleMark(x: .value("Разрыв", gap.date))
                    .foregroundStyle(theme.danger.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(x: .value("Разрыв", gap.date), y: .value("Остаток", -gap.amount))
                    .foregroundStyle(theme.danger)
                    .symbolSize(90)
                    // Label ABOVE the point: the gap sits at the trough (bottom of the domain), so a
                    // `.bottom` annotation would render into the axis region / clip off the frame.
                    .annotation(position: .top, alignment: .center, spacing: 2) {
                        Text("разрыв")
                            .font(BrandFont.micro)
                            .foregroundStyle(theme.danger)
                    }
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(theme.border)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(Self.compact(amount))
                            .font(BrandFont.micro)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                AxisGridLine().foregroundStyle(theme.border)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated))
                            .font(BrandFont.micro)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .frame(height: 196)
        .accessibilityLabel("Прогноз денежного потока на 90 дней")
    }

    /// Flat, quiet fill under the line (DESIGN §2: no decorative gradients).
    private var areaFill: Color { theme.textPrimary.opacity(0.06) }

    /// Y domain with headroom below the trough and above the peak (keeps the gap marker off the edge).
    private var yDomain: ClosedRange<Double> {
        let low = min(scenario.minBalance, 0)
        let high = max(scenario.maxBalance, 0)
        let pad = max((high - low) * 0.12, 100_000)
        return (low - pad)...(high + pad)
    }

    /// Signed compact ₽ axis label via ``MoneyFormat``: «2,8 млн» / «−1,2 млн» / «320 тыс.».
    static func compact(_ value: Double) -> String {
        MoneyFormat.compact(value, currency: nil)
    }
}
