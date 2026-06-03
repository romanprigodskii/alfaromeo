import SwiftUI

/// Payment + amortisation preview (§10.5 «расчёт платежа/графика»). Three summary tiles (платёж /
/// переплата / всего) over the first months of the schedule, with the principal/interest split and
/// the running balance. Compact, monospaced numerals.
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
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                summaryTile(title: "Платёж/мес", value: CreditFormat.rub(monthlyPayment), tint: theme.accent)
                summaryTile(title: interestFree ? "Без переплаты" : "Переплата",
                            value: interestFree ? "0 ₽" : CreditFormat.rub(overpay),
                            tint: interestFree ? theme.success : theme.warning)
                summaryTile(title: "Всего", value: CreditFormat.rub(total), tint: theme.textPrimary)
            }

            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    headerRow
                    Divider().overlay(theme.border)
                    ForEach(shown) { row in
                        scheduleRow(row)
                        if row.id != shown.last?.id { Divider().overlay(theme.border.opacity(0.5)) }
                    }
                    if rows.count > previewCount {
                        Text("…ещё \(rows.count - previewCount) " + monthsWord(rows.count - previewCount))
                            .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing.sm)
                    }
                }
            }
        }
    }

    private func summaryTile(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            Text(value).font(BrandFont.mono(15, weight: .semibold)).foregroundStyle(tint)
                .minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private var headerRow: some View {
        HStack(spacing: Spacing.xs) {
            cell("Мес", width: 34, align: .leading)
            cell("Платёж", align: .trailing)
            cell("Долг", align: .trailing)
            cell("%", align: .trailing)
            cell("Остаток", align: .trailing)
        }
        .font(BrandFont.micro)
        .foregroundStyle(theme.textSecondary)
        .padding(.vertical, Spacing.xs)
    }

    private func scheduleRow(_ row: ScheduleRow) -> some View {
        HStack(spacing: Spacing.xs) {
            cell("\(row.index)", width: 34, align: .leading)
            cell(short(row.payment), align: .trailing)
            cell(short(row.principalPart), align: .trailing)
            cell(short(row.interestPart), align: .trailing)
            cell(short(row.balance), align: .trailing)
        }
        .font(BrandFont.mono(12, weight: .medium))
        .foregroundStyle(theme.textPrimary)
        .padding(.vertical, Spacing.xs)
    }

    private func cell(_ text: String, width: CGFloat? = nil, align: Alignment) -> some View {
        Text(text)
            .lineLimit(1).minimumScaleFactor(0.6)
            .frame(width: width, alignment: align)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: align)
    }

    /// Compact ₽ for the dense table: «24,6 т» / «1,82 млн».
    private func short(_ value: Double) -> String {
        switch value {
        case 1_000_000...: return String(format: "%.2f млн", value / 1_000_000)
        case 1_000...:     return String(format: "%.1f т", value / 1_000)
        default:           return "\(Int(value.rounded()))"
        }
    }

    private func monthsWord(_ n: Int) -> String {
        let n10 = n % 10, n100 = n % 100
        if n10 == 1 && n100 != 11 { return "месяц" }
        if (2...4).contains(n10) && !(12...14).contains(n100) { return "месяца" }
        return "месяцев"
    }
}
