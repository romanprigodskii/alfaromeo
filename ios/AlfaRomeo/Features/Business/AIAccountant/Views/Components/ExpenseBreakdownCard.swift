import SwiftUI

/// Expense analysis + auto-classification insight (§8.2): the monthly spend split by category with a
/// share bar, plus a note on how many operations the AI classified. «Разобрать» asks Claude for advice.
struct ExpenseBreakdownCard: View {
    let scenario: CashflowScenario
    var onAsk: () -> Void

    @Environment(\.theme) private var theme

    private var maxShare: Int { scenario.expenses.map(\.sharePercent).max() ?? 100 }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Text("Анализ расходов")
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text("за месяц").font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                }

                VStack(spacing: Spacing.sm) {
                    ForEach(scenario.expenses.prefix(4)) { cat in
                        row(cat)
                    }
                }

                Text("Разобрано операций: \(scenario.classifiedOpsCount), на уточнении: \(scenario.needsReviewCount)")
                    .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onAsk) {
                    Text("Спросить, где сэкономить")
                        .font(BrandFont.body(15, weight: .medium))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(_ cat: ExpenseCategory) -> some View {
        VStack(spacing: Spacing.xxs) {
            HStack {
                Text(cat.label).font(BrandFont.subheadline).foregroundStyle(theme.textPrimary)
                Spacer()
                Text(MoneyFormat.percent(Double(cat.sharePercent))).font(BrandFont.subheadline.weight(.medium))
                    .foregroundStyle(theme.textPrimary).monospacedDigit()
                Text(BizFormat.compactRuble(cat.amount)).font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
                    .frame(width: 84, alignment: .trailing)
            }
            ProgressBar(value: Double(cat.sharePercent) / Double(max(maxShare, 1)), height: 4)
        }
    }
}
