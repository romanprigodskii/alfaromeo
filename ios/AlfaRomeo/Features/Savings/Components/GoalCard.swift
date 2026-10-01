import SwiftUI

/// One savings goal as a row of the hub's «Цели» ``GroupedSection`` (§10.6 «Цели с прогрессом и
/// авто-пополнением», облегчённо): progress, auto-top-up status and a «Пополнить» action.
struct GoalCard: View {
    let goal: SavingsGoal
    var onTopUp: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm + 4) {
            GlyphCircle(text: goal.emoji)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.title)
                            .font(BrandFont.bodyM)
                            .foregroundStyle(theme.textPrimary)
                        Text("\(SavingsFormat.rub(goal.current)) из \(SavingsFormat.rub(goal.target))")
                            .font(BrandFont.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer(minLength: Spacing.sm)
                    Text(MoneyFormat.percent(goal.progress * 100, maxFractionDigits: 0))
                        .font(BrandFont.bodyM)
                        .monospacedDigit()
                        .foregroundStyle(theme.textPrimary)
                }

                ProgressBar(value: goal.progress, tint: goal.isComplete ? theme.success : theme.accent)

                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text(statusLine)
                        .font(BrandFont.footnote)
                        .monospacedDigit()
                        .foregroundStyle(goal.isComplete ? theme.success : theme.textSecondary)
                    Spacer(minLength: 0)
                    if !goal.isComplete {
                        Button("Пополнить", action: onTopUp)
                            .font(BrandFont.body(15, weight: .medium))
                            .foregroundStyle(theme.accent)
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .groupedRowTextInset(48)
    }

    private var statusLine: String {
        if goal.isComplete { return "Цель достигнута" }
        guard goal.autoTopUpEnabled, let monthly = goal.autoTopUpMonthly else {
            return "Авто-пополнение выключено"
        }
        var line = "Авто +\(SavingsFormat.rub(monthly))/мес"
        if let months = goal.monthsToTarget { line += ", ещё\(MoneyFormat.nbsp)\(months)\(MoneyFormat.nbsp)мес" }
        return line
    }
}

#Preview {
    GroupedSection("Цели") {
        GoalCard(goal: SavingsGoal(id: "g1", profileId: "p", title: "Подушка безопасности",
                                   emoji: "🛟", target: 300_000, current: 184_000,
                                   autoTopUpMonthly: 15_000)) {}
        GoalCard(goal: SavingsGoal(id: "g2", profileId: "p", title: "Отпуск 2035",
                                   emoji: "✈️", target: 200_000, current: 200_000,
                                   autoTopUpMonthly: nil)) {}
    }
    .padding()
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
