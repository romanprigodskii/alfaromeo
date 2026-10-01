import SwiftUI

/// Create a savings goal with optional auto-top-up (§10.6, облегчённо). On save the goal lands in
/// ``SavingsStore`` and shows in the hub with a live progress bar.
struct NewGoalView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router

    @State private var store = SavingsStore.shared
    @State private var title = ""
    @State private var emoji = "🎯"
    @State private var target: Double = 100_000
    @State private var autoOn = true
    @State private var monthly: Double = 10_000

    private let emojis = ["🎯", "🛟", "✈️", "🏠", "🚗", "🎓", "💍", "🎁"]
    private var profileId: String { session.activeProfile?.id ?? "" }

    private var monthsToTarget: Int? {
        guard autoOn, monthly > 0 else { return nil }
        return Int((target / monthly).rounded(.up))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    emojiPicker
                    titleField
                    targetField
                    autoTopUpSection
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.md)
            }
            footer
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Новая цель")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 2) {
            SectionHeader("Иконка")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(emojis, id: \.self) { item in
                        Button { withAnimation(Motion.snappy) { emoji = item } } label: {
                            Text(item).font(.system(size: 24))
                                .frame(width: 48, height: 48)
                                .background(emoji == item ? theme.fill : theme.surface, in: Circle())
                                .overlay(Circle().stroke(emoji == item ? theme.accent : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityAddTraits(emoji == item ? .isSelected : [])
                    }
                }
                .padding(2)
            }
        }
    }

    private var titleField: some View {
        GroupedSection("Название") {
            TextField("Например, Отпуск 2035", text: $title)
                .font(BrandFont.bodyM)
                .foregroundStyle(theme.textPrimary)
                .frame(minHeight: Spacing.rowMinHeight)
        }
    }

    private var targetField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 2) {
            SectionHeader("Сумма цели")
            SurfaceCard {
                SavingsAmountField(amount: $target, symbol: "₽",
                                   presets: [100_000, 300_000, 1_000_000].map {
                                       AmountPreset(label: SavingsFormat.rub($0), value: $0)
                                   })
            }
        }
    }

    private var autoTopUpSection: some View {
        GroupedSection("Авто-пополнение",
                       footer: monthsToTarget.map { "Цель достижима за \($0)\(MoneyFormat.nbsp)мес" }) {
            Toggle(isOn: $autoOn.animation(Motion.snappy)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Откладывать каждый месяц").font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    Text("Перевод в начале месяца").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                }
            }
            .tint(theme.accent)
            .padding(.vertical, Spacing.rowVertical)

            if autoOn {
                SavingsAmountField(amount: $monthly, symbol: "₽/мес",
                                   presets: [5_000, 10_000, 25_000].map {
                                       AmountPreset(label: SavingsFormat.rub($0), value: $0)
                                   })
                    .padding(.vertical, Spacing.md)
            }
        }
    }

    private var footer: some View {
        PrimaryButton(title: "Создать цель") { create() }
            .disabled(target <= 0)
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.sm)
            .background(theme.background)
    }

    private func create() {
        let goal = SavingsGoal(
            id: store.nextGoalId(),
            profileId: profileId,
            title: title.trimmingCharacters(in: .whitespaces).isEmpty ? "Моя цель" : title,
            emoji: emoji,
            target: target,
            current: 0,
            autoTopUpMonthly: autoOn ? monthly : nil)
        store.addGoal(goal)
        router.pop()
    }
}

#Preview {
    NavigationStack {
        NewGoalView()
    }
    .environment(AppSession.mockAuthenticated())
    .environment(\.apiClient, MockAPIClient())
    .environment(\.theme, .default)
    .environment(Router())
}
