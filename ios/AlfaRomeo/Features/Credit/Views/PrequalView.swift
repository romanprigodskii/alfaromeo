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
            VStack(spacing: Spacing.lg) {
                hero
                factorsSection
                simulatorSection
                rateNote
                footer
            }
            .padding(Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Преквалификация")
        .navigationBarTitleDisplayMode(.inline)
        .creditExitToolbar()
        .task(id: profileId) { store.load(profileId: profileId) }
    }

    // MARK: Hero — simulated limit + Δ

    private var hero: some View {
        VStack(spacing: Spacing.sm) {
            LimitGauge(
                title: hasApplied ? "Лимит с учётом изменений" : "Ваш одобренный лимит",
                amount: simulatedLimit,
                ceiling: product.maxAmount,
                rateLabel: "≈ \(CreditFormat.percent(simulatedRate))",
                delta: simulatedLimit - baseLimit)
            Text("Решение объяснимо: вот из чего складывается лимит и что на него влияет.")
                .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Factors (§10.5 факторы решения)

    private var factorsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Почему такое решение", subtitle: "Три фактора — нажмите, чтобы раскрыть")
            ForEach(store.factors(simulated: true)) { factor in
                FactorRow(factor: factor)
            }
        }
    }

    // MARK: Simulator (§10.5 «если закрыть карту X — лимит +Y»)

    private var simulatorSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader("Что если…", subtitle: "Подберите шаги — лимит пересчитается")
                if hasApplied {
                    Button("Сбросить") {
                        withAnimation(Motion.snappy) { store.appliedLevers.removeAll() }
                    }
                    .font(BrandFont.callout.weight(.semibold)).foregroundStyle(theme.accent)
                    .buttonStyle(PressableButtonStyle())
                }
            }
            ForEach(store.levers) { lever in
                SimulatorLeverRow(
                    lever: lever,
                    delta: store.delta(of: lever, for: product),
                    isOn: store.isApplied(lever.id)
                ) {
                    withAnimation(Motion.snappy) { store.toggleLever(lever.id) }
                }
            }
            Text("Это моделирование: оформление считается по текущему лимиту, без учёта неподтверждённых шагов.")
                .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rateNote: some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "percent").foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Персональная ставка \(CreditFormat.rate(simulatedRate))")
                        .font(BrandFont.callout.weight(.semibold)).foregroundStyle(theme.textPrimary)
                    Text("Чем выше скоринг и ниже нагрузка — тем ближе ставка к минимальной по продукту (\(CreditFormat.rate(product.minRate))).")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            PrimaryButton(title: "Оформить — выбрать сумму", icon: "arrow.right") {
                router.push(CreditRoute.apply(productId: product.id))
            }
            Text("Преодобрено \(CreditFormat.rub(baseLimit)) · в заявке можно выбрать сумму до \(CreditFormat.rub(requestable))")
                .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Spacing.xs)
    }

    private func sectionHeader(_ title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(BrandFont.title).foregroundStyle(theme.textPrimary)
            if let subtitle {
                Text(subtitle).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
