import SwiftUI
import Charts

/// Income vs. expense per month as grouped bars (§9.4 столбчатая диаграмма, the «Вся аналитика» tab).
/// Colours follow the signed-amount rule (docs/DESIGN.md §6): income in `success`, expenses in ink,
/// since spending is normal life rather than an error. The foreground-style scale drives the legend.
struct MonthlyBarChart: View {
    let summaries: [MonthlySummary]

    @Environment(\.theme) private var theme

    private let incomeKey = "Доходы"
    private let expenseKey = "Расходы"

    var body: some View {
        Chart {
            ForEach(summaries) { month in
                BarMark(
                    x: .value("Месяц", month.label),
                    y: .value("Сумма", month.income)
                )
                .position(by: .value("Тип", incomeKey))
                .foregroundStyle(by: .value("Тип", incomeKey))
                .cornerRadius(3)

                BarMark(
                    x: .value("Месяц", month.label),
                    y: .value("Сумма", month.expense)
                )
                .position(by: .value("Тип", expenseKey))
                .foregroundStyle(by: .value("Тип", expenseKey))
                .cornerRadius(3)
            }
        }
        .chartForegroundStyleScale([incomeKey: theme.success, expenseKey: theme.textPrimary])
        .chartLegend(position: .top, alignment: .leading, spacing: Spacing.sm)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(theme.border)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(MonthlyBarChart.compact(amount))
                            .font(BrandFont.micro)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            }
        }
        .frame(height: 240)
        .accessibilityLabel("Доходы и расходы по месяцам")
    }

    /// «1,2 млн» / «320 тыс.»: compact axis labels through the central ``MoneyFormat``.
    static func compact(_ value: Double) -> String {
        MoneyFormat.compact(abs(value), currency: nil)
    }
}

#Preview {
    let summaries = [
        MonthlySummary(monthKey: "2035-05", date: .distantPast, income: 210_000, expense: 90_000),
        MonthlySummary(monthKey: "2035-06", date: .now, income: 45_000, expense: 14_000),
    ]
    return MonthlyBarChart(summaries: summaries)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
        .environment(\.theme, .default)
}
