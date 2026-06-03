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
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    emojiPicker
                    titleField
                    targetField
                    autoTopUpCard
                }
                .padding(Spacing.md)
            }
            footer
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Новая цель")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Иконка").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(emojis, id: \.self) { item in
                        Button { withAnimation(Motion.snappy) { emoji = item } } label: {
                            Text(item).font(.system(size: 26))
                                .frame(width: 48, height: 48)
                                .background(emoji == item ? theme.accent.opacity(0.18) : theme.elevated,
                                            in: RoundedRectangle(cornerRadius: Radius.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.md)
                                        .stroke(emoji == item ? theme.accent : .clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Название").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            SurfaceCard {
                TextField("Например, Отпуск 2035", text: $title)
                    .font(BrandFont.body())
                    .foregroundStyle(theme.textPrimary)
            }
        }
    }

    private var targetField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Цель").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            SurfaceCard {
                SavingsAmountField(amount: $target, symbol: "₽",
                                   presets: [.init(label: "100 000", value: 100_000),
                                             .init(label: "300 000", value: 300_000),
                                             .init(label: "1 000 000", value: 1_000_000)])
            }
        }
    }

    private var autoTopUpCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Авто-пополнение").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            SurfaceCard {
                VStack(spacing: Spacing.sm) {
                    Toggle(isOn: $autoOn.animation(Motion.snappy)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Откладывать каждый месяц").font(BrandFont.callout).foregroundStyle(theme.textPrimary)
                            Text("Автоматический перевод в начале месяца").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                        }
                    }
                    .tint(theme.accent)

                    if autoOn {
                        Divider().overlay(theme.border)
                        SavingsAmountField(amount: $monthly, symbol: "₽/мес",
                                           presets: [.init(label: "5 000", value: 5_000),
                                                     .init(label: "10 000", value: 10_000),
                                                     .init(label: "25 000", value: 25_000)])
                        if let months = monthsToTarget {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "flag.checkered").foregroundStyle(theme.accent)
                                Text("Цель достижима за \(months) мес").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        PrimaryButton(title: "Создать цель", icon: "checkmark") { create() }
            .disabled(target <= 0)
            .opacity(target > 0 ? 1 : 0.5)
            .padding(Spacing.md)
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
