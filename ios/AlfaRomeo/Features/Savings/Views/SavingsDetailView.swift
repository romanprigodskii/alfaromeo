import SwiftUI

/// Detail of one active вклад / стейк (§10.6 «Список активных вкладов/стейков»). Read-mostly: terms,
/// live ₽ valuation for stakes, lock countdown, projected yearly yield, and a demo top-up for
/// top-up-eligible ruble deposits.
struct SavingsDetailView: View {
    let depositId: String

    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router

    @State private var store = SavingsStore.shared
    @State private var toast: String?

    private var deposit: Deposit? { store.deposit(id: depositId) }

    var body: some View {
        ScrollView {
            if let deposit {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    hero(deposit)
                    terms(deposit)
                    if canTopUp(deposit) {
                        PrimaryButton(title: "Пополнить на \(SavingsFormat.rub(Self.topUpStep))") {
                            store.topUpDeposit(id: deposit.id, by: Self.topUpStep)
                            flash("Пополнено на \(SavingsFormat.rub(Self.topUpStep))")
                        }
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xl)
            } else {
                ContentUnavailableView("Продукт не найден", systemImage: "tray",
                                       description: Text("Этот вклад или стейк больше не доступен."))
                    .padding(Spacing.xl)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(deposit.map(title) ?? "Детали")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let toast {
                StatusPill(status: .success, text: toast)
                    .padding(.bottom, Spacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private static let topUpStep: Double = 10_000

    // MARK: Sections

    private func hero(_ deposit: Deposit) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(isStake(deposit) ? "Стоимость стейка" : "Сумма вклада")
                .font(BrandFont.subheadline)
                .foregroundStyle(theme.textSecondary)
            AmountText(amount: valueRub(deposit), size: 40, splitsKopecks: true)
                .contentTransition(.numericText())
            if isStake(deposit) {
                Text(SavingsFormat.units(deposit.principal, asset: deposit.asset ?? ""))
                    .font(BrandFont.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Motion.snappy, value: valueRub(deposit))
    }

    /// Terms with the honest risk note as the footer: АСВ insurance for a deposit, market risk for
    /// a stake.
    private func terms(_ deposit: Deposit) -> some View {
        let risk: SavingsRisk = isStake(deposit) ? .marketRisk : .insuredASV
        return GroupedSection("Условия", footer: risk.detail) {
            row(isStake(deposit) ? "APY" : "Ставка", SavingsFormat.percent(deposit.rateApy))
            if let term = deposit.term { row("Срок", "\(term) мес") }
            if let days = daysUntil(deposit.lockUntil) {
                row(isStake(deposit) ? "Lock" : "До выплаты", days > 0 ? "\(days) дн" : "Завершается")
            }
            row("Доход за год", "≈ \(SavingsFormat.rub(projectedYearlyRub(deposit)))")
        }
    }

    // MARK: Derived

    private func isStake(_ d: Deposit) -> Bool { d.kind == .stake }

    private func valueRub(_ d: Deposit) -> Double {
        switch d.kind {
        case .ruble: return d.principal
        case .stake: return store.rubValue(units: d.principal, asset: d.asset ?? "")
        }
    }

    private func projectedYearlyRub(_ d: Deposit) -> Double {
        valueRub(d) * (d.rateApy / 100)
    }

    private func canTopUp(_ d: Deposit) -> Bool {
        guard d.kind == .ruble else { return false }
        return SavingsCatalog.depositProducts.contains { $0.allowsTopUp }  // demo: top-up shown for ruble
    }

    private func title(_ d: Deposit) -> String {
        d.kind == .stake ? "Стейкинг \(d.asset ?? "")" : "Рублёвый вклад"
    }

    private func daysUntil(_ iso: String?) -> Int? {
        guard let iso, let date = ISO8601DateFormatter().date(from: iso) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day
        return days.map { max($0, 0) }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(BrandFont.bodyM).foregroundStyle(theme.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(value).font(BrandFont.bodyM).monospacedDigit().foregroundStyle(theme.textPrimary)
        }
        .frame(minHeight: Spacing.rowMinHeight)
    }

    private func flash(_ text: String) {
        withAnimation(Motion.smooth) { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(Motion.smooth) { toast = nil }
        }
    }
}

#Preview {
    NavigationStack {
        SavingsDetailView(depositId: "d2")
    }
    .environment(AppSession.mockAuthenticated())
    .environment(\.apiClient, MockAPIClient())
    .environment(\.theme, .default)
    .environment(Router())
}
