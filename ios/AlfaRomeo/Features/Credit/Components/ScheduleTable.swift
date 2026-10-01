import SwiftUI

/// Payment + amortisation preview (§10.5 «расчёт платежа/графика»). A grouped summary (платёж /
/// переплата / всего) over the first months of the schedule, with the principal/interest split and
/// the running balance in tabular figures.
struct ScheduleTable: View {
    let monthlyPayment: Double
    let overpay: Double
    let total: Double
    let rows: [ScheduleRow]
    var previewCount: Int = 6
    var interestFree: Bool = false

    @Environment(\.theme) private var theme

    private var shown: [ScheduleRow] { Array(rows.prefix(previewCount)) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            GroupedSection {
                ListRow(title: "Платёж в месяц", value: CreditFormat.rub(monthlyPayment))
                ListRow(title: "Переплата", value: interestFree ? CreditFormat.rub(0) : CreditFormat.rub(overpay))
                ListRow(title: "Всего выплат", value: CreditFormat.rub(total))
            }

            VStack(alignment: .leading, spacing: Spacing.sm + 2) {
                SectionHeader("График")
                SurfaceCard {
                    VStack(spacing: 0) {
                        headerRow
                        Hairline()
                        ForEach(shown) { row in
                            scheduleRow(row)
                            if row.id != shown.last?.id { Hairline() }
                        }
                    }
                }
                if rows.count > previewCount {
                    Text("Ещё \(rows.count - previewCount) " + monthsWord(rows.count - previewCount))
                        .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, Spacing.md)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: Spacing.sm) {
            cell("Мес", width: 30, align: .leading)
            cell("Платёж", align: .trailing)
            cell("Долг", align: .trailing)
            cell("Проценты", align: .trailing)
            cell("Остаток", align: .trailing)
        }
        .font(BrandFont.micro)
        .foregroundStyle(theme.textSecondary)
        .padding(.bottom, Spacing.sm)
    }

    private func scheduleRow(_ row: ScheduleRow) -> some View {
        HStack(spacing: Spacing.sm) {
            cell("\(row.index)", width: 30, align: .leading)
                .foregroundStyle(theme.textSecondary)
            cell(short(row.payment), align: .trailing)
            cell(short(row.principalPart), align: .trailing)
            cell(short(row.interestPart), align: .trailing)
            cell(short(row.balance), align: .trailing)
        }
        .font(BrandFont.body(13))
        .monospacedDigit()
        .foregroundStyle(theme.textPrimary)
        .padding(.vertical, Spacing.sm + 2)
    }

    private func cell(_ text: String, width: CGFloat? = nil, align: Alignment) -> some View {
        Text(text)
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(width: width, alignment: align)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: align)
    }

    /// Whole rubles with Russian grouping for the dense table: «24 612», «1 196 300».
    private func short(_ value: Double) -> String {
        MoneyFormat.number(value.rounded(), maxFractionDigits: 0)
    }

    private func monthsWord(_ n: Int) -> String {
        let n10 = n % 10, n100 = n % 100
        if n10 == 1 && n100 != 11 { return "месяц" }
        if (2...4).contains(n10) && !(12...14).contains(n100) { return "месяца" }
        return "месяцев"
    }
}
