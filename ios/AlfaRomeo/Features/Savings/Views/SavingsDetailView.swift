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
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    hero(deposit)
                    terms(deposit)
                    if isStake(deposit) { riskNote } else { insuredNote }
                    if canTopUp(deposit) {
                        PrimaryButton(title: "Пополнить · 10 000 ₽", icon: "plus") {
                            store.topUpDeposit(id: deposit.id, by: 10_000)
                            flash("Пополнено на 10 000 ₽")
                        }
                    }
                }
                .padding(Spacing.md)
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

    // MARK: Sections

    private func hero(_ deposit: Deposit) -> some View {
        SurfaceCard(elevated: true) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(isStake(deposit) ? "Стоимость стейка (live)" : "Сумма вклада")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                AmountText(amount: valueRub(deposit), size: 30).contentTransition(.numericText())
                if isStake(deposit) {
                    Text(SavingsFormat.units(deposit.principal, asset: deposit.asset ?? ""))
                        .font(BrandFont.mono(14)).foregroundStyle(theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(Motion.snappy, value: valueRub(deposit))
        }
    }

    private func terms(_ deposit: Deposit) -> some View {
        SurfaceCard {
            VStack(spacing: Spacing.sm) {
                row("Ставка / APY", SavingsFormat.percent(deposit.rateApy), tint: theme.success)
                if let term = deposit.term { row("Срок", "\(term) мес") }
                if let days = daysUntil(deposit.lockUntil) {
                    row(isStake(deposit) ? "Lock" : "До выплаты", days > 0 ? "\(days) дн" : "завершается")
                }
                Divider().overlay(theme.border)
                row("Прогноз дохода за год", "≈ \(SavingsFormat.rub(projectedYearlyRub(deposit)))", tint: theme.success)
            }
        }
    }

    private var insuredNote: some View {
        noteCard(SavingsRisk.insuredASV, tint: theme.success)
    }
    private var riskNote: some View {
        noteCard(SavingsRisk.marketRisk, tint: theme.warning)
    }

    private func noteCard(_ risk: SavingsRisk, tint: Color) -> some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: risk.systemImage).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(risk.headline).font(BrandFont.callout).foregroundStyle(theme.textPrimary)
                    Text(risk.detail).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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

    private func row(_ label: String, _ value: String, tint: Color? = nil) -> some View {
        HStack {
            Text(label).font(BrandFont.body()).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value).font(BrandFont.body().weight(.semibold)).foregroundStyle(tint ?? theme.textPrimary)
        }
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
