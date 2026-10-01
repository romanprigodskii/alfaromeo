import SwiftUI

/// Explainable пре-квалификация (§10.5 «факторы решения + симулятор»). The approved limit on top,
/// the three factors that produced it (доход / нагрузка / история) — each tappable for «почему так»
/// and «что улучшить» — and a what-if simulator below: toggling a lever («закрыть карту X»,
/// «подтвердить доход») recomputes the limit live, and the hero animates by the exact derived Δ.
/// Anchored on the cash product (the «главный» offering); levers are educational — they don't change
/// your real obligations, so оформление still uses the base limit.
struct PrequalView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router

    @State private var store = CreditStore.shared

    private let product = CreditCatalog.primary
    private var profileId: String { session.activeProfile?.id ?? "" }

    private var baseLimit: Double { store.approvedLimit(for: product, simulated: false) }
    /// Ceiling the client may self-request in the application (§10.5, «до 2 млн»).
    private var requestable: Double { CreditStore.requestableLimit(for: product, preApproved: baseLimit) }
    private var simulatedLimit: Double { store.approvedLimit(for: product, simulated: true) }
    private var simulatedRate: Double { store.personalRate(for: product, simulated: true) }
    private var hasApplied: Bool { !store.appliedLevers.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                hero
                factorsSection
                simulatorSection
                footer
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Преквалификация")
        .navigationBarTitleDisplayMode(.inline)
        .creditExitToolbar()
        .task(id: profileId) { store.load(profileId: profileId) }
    }

    // MARK: Hero: simulated limit + Δ

    private var hero: some View {
        LimitGauge(
            title: hasApplied ? "Лимит с учётом изменений" : "Одобренный лимит",
            amount: simulatedLimit,
            ceiling: product.maxAmount,
            rateLabel: "≈ \(CreditFormat.percent(simulatedRate))",
            delta: simulatedLimit - baseLimit)
    }

    // MARK: Factors (§10.5 факторы решения) + personal rate

    private var factorsSection: some View {
        GroupedSection("Факторы решения", footer: rateFooter) {
            ForEach(store.factors(simulated: true)) { factor in
                FactorRow(factor: factor)
            }
        }
    }

    private var rateFooter: String {
        "Персональная ставка \(CreditFormat.rate(simulatedRate)). Чем выше скоринг и ниже нагрузка, "
        + "тем ближе ставка к минимальной по продукту: \(CreditFormat.rate(product.minRate))."
    }

    // MARK: Simulator (§10.5 «если закрыть карту X, лимит +Y»)

    private var simulatorSection: some View {
        GroupedSection("Симулятор лимита",
                       actionTitle: hasApplied ? "Сбросить" : nil,
                       action: resetAction,
                       footer: "Это моделирование: оформление считается по текущему лимиту, без неподтверждённых шагов.") {
            ForEach(store.levers) { lever in
                SimulatorLeverRow(
                    lever: lever,
                    delta: store.delta(of: lever, for: product),
                    isOn: store.isApplied(lever.id)
                ) {
                    withAnimation(Motion.snappy) { store.toggleLever(lever.id) }
                }
            }
        }
    }

    private var resetAction: (() -> Void)? {
        guard hasApplied else { return nil }
        return { withAnimation(Motion.snappy) { store.appliedLevers.removeAll() } }
    }

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton(title: "Выбрать сумму") {
                router.push(CreditRoute.apply(productId: product.id))
            }
            Text("Предодобрено \(CreditFormat.rub(baseLimit)). В заявке можно выбрать сумму до \(CreditFormat.rub(requestable)).")
                .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        PrequalView()
    }
    .environment(AppSession.mockAuthenticated())
    .environment(\.theme, .default)
    .environment(Router())
}
