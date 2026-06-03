import SwiftUI

/// A savings goal with a progress bar + auto-top-up status (§10.6 «Цели с прогрессом и
/// авто-пополнением», облегчённо).
struct GoalCard: View {
    let goal: SavingsGoal
    var onTopUp: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Text(goal.emoji).font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(goal.title).font(BrandFont.callout).foregroundStyle(theme.textPrimary)
                        Text("\(SavingsFormat.rub(goal.current)) из \(SavingsFormat.rub(goal.target))")
                            .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Text(String(format: "%.0f%%", goal.progress * 100))
                        .font(BrandFont.mono(15, weight: .semibold))
                        .foregroundStyle(goal.isComplete ? theme.success : theme.accent)
                }

                ProgressBar(value: goal.progress, tint: goal.isComplete ? theme.success : theme.accent)

                HStack(spacing: Spacing.sm) {
                    if goal.autoTopUpEnabled, let monthly = goal.autoTopUpMonthly {
                        SavingsChip(text: "авто +\(SavingsFormat.rub(monthly))/мес",
                                    systemImage: "arrow.triangle.2.circlepath", tint: theme.accent)
                        if let months = goal.monthsToTarget {
                            SavingsChip(text: "цель через \(months) мес", systemImage: "flag.checkered")
                        }
                    } else if goal.isComplete {
                        SavingsChip(text: "Цель достигнута", systemImage: "checkmark.seal.fill", tint: theme.success)
                    } else {
                        SavingsChip(text: "авто-пополнение выкл.", systemImage: "pause.circle")
                    }
                    Spacer(minLength: 0)
                    if !goal.isComplete {
                        Button(action: onTopUp) {
                            Text("Пополнить").font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.accent)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.sm) {
        GoalCard(goal: SavingsGoal(id: "g1", profileId: "p", title: "Подушка безопасности",
                                   emoji: "🛟", target: 300_000, current: 184_000,
                                   autoTopUpMonthly: 15_000)) {}
        GoalCard(goal: SavingsGoal(id: "g2", profileId: "p", title: "Отпуск 2035",
                                   emoji: "✈️", target: 200_000, current: 200_000,
                                   autoTopUpMonthly: nil)) {}
    }
    .padding()
    .environment(\.theme, .default)
}
