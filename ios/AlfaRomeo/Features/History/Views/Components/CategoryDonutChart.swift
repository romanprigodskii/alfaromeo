import SwiftUI
import Charts

/// Category breakdown as a donut (§9.4 круговая диаграмма на Swift Charts). Each sector is coloured by
/// its category tint, which is the chart's legend: the category list repeats it on each row's bar.
/// The hole shows the period total and a caption.
struct CategoryDonutChart: View {
    let slices: [CategorySlice]
    let total: Double
    let centerCaption: String

    @Environment(\.theme) private var theme

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Сумма", slice.amount),
                innerRadius: .ratio(0.62),
                angularInset: 1.6
            )
            .cornerRadius(4)
            .foregroundStyle(slice.category.tint)
        }
        .chartLegend(.hidden)
        .frame(height: 230)
        .overlay {
            VStack(spacing: 2) {
                Text(centerCaption)
                    .font(BrandFont.footnote)
                    .foregroundStyle(theme.textSecondary)
                AmountText(amount: total, size: 22)
            }
        }
        .accessibilityLabel("Диаграмма по категориям")
        .accessibilityValue(slices.map { "\($0.category.title): \(Int(($0.percent(of: total) * 100).rounded())) процентов" }
            .joined(separator: ", "))
    }
}

#Preview {
    let slices = [
        CategorySlice(category: CategoryRef(.groceries), amount: 12_000, count: 4),
        CategorySlice(category: CategoryRef(.marketplace), amount: 7_800, count: 1),
        CategorySlice(category: CategoryRef(.subscriptions), amount: 1_800, count: 3),
        CategorySlice(category: CategoryRef(.dining), amount: 3_200, count: 2),
    ]
    return CategoryDonutChart(slices: slices, total: 24_800, centerCaption: "Расходы")
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
        .environment(\.theme, .default)
}
