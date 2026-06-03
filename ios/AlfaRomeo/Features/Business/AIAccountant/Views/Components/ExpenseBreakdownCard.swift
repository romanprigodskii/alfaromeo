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
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(theme.cryptoGradient, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    Text("Анализ расходов")
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text("за месяц").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                }

                VStack(spacing: Spacing.sm) {
                    ForEach(scenario.expenses.prefix(4)) { cat in
                        row(cat)
                    }
                }

                HStack(spacing: Spacing.xs) {
                    Image(systemName: "wand.and.stars").font(.system(size: 11, weight: .bold)).foregroundStyle(theme.textSecondary)
                    Text("AI классифицировал \(scenario.classifiedOpsCount) операций · \(scenario.needsReviewCount) требуют уточнения")
                        .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onAsk) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "sparkles").font(.system(size: 12, weight: .bold))
                        Text("Где сэкономить — спросить AI").font(BrandFont.caption.weight(.semibold))
                    }
                    .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(_ cat: ExpenseCategory) -> some View {
        VStack(spacing: Spacing.xxs) {
            HStack {
                Text(cat.label).font(BrandFont.caption).foregroundStyle(theme.textPrimary)
                Spacer()
                Text("\(cat.sharePercent)%").font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.textPrimary)
                Text(BizFormat.compactRuble(cat.amount)).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    .frame(width: 72, alignment: .trailing)
            }
            ProgressBar(value: Double(cat.sharePercent) / Double(max(maxShare, 1)), useCryptoGradient: true, height: 6)
        }
    }
}
