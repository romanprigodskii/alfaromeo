import SwiftUI

/// «Накопления» (spec name «Приумножить»): the savings + staking hub (§10.6). Ruble deposits and
/// crypto staking sit side by side, each section footer stating the honest АСВ-vs-рыночный-риск
/// contrast; APY is tier-boosted (§4, premium on Infinite); goals show progress + auto-top-up; and
/// the active list reflects the ``Deposit`` contract.
///
/// Entry point: `HomeRoute.deposits` resolves to this view (one-line wiring in Home). The hub
/// registers its own sub-routes via `.navigationDestination(for: SavingsRoute.self)`.
struct SavingsHubView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router

    @State private var store = SavingsStore.shared

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var tier: Tier { session.currentTier(for: profileId, fallback: store.baseTier) }
    private var isPremium: Bool { SavingsRates.hasPremiumApy(tier) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                header
                goalsSection
                depositsSection
                stakingSection
                activeSection
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xxl)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Накопления")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: SavingsRoute.self) { $0.destination }
        .task(id: profileId) { await store.load(api: api, profileId: profileId) }
        .task { await store.streamPrices() }
    }

    // MARK: Header: total + tier (premium APY / upsell, §4)

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("В работе")
                    .font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)
                AmountText(amount: store.totalValueRub, size: 40, splitsKopecks: true)
                    .contentTransition(.numericText())
                if isPremium {
                    Text("Повышенные ставки на тарифе \(tier.displayName)")
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .animation(Motion.snappy, value: store.totalValueRub)

            if !isPremium {
                UpsellCard(
                    title: "Повышенные ставки на Infinite",
                    message: "Вклады +\(SavingsFormat.points(SavingsRates.depositUpliftToTop(from: tier))) к ставке, стейкинг до +\(SavingsFormat.points(SavingsRates.stakeUpliftToTop(from: tier))) к APY",
                    recommendedTier: .infinite
                )
            }
        }
    }

    // MARK: Goals (§10.6)

    @ViewBuilder
    private var goalsSection: some View {
        if store.goals.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader("Цели", actionTitle: "Новая цель") { router.push(SavingsRoute.newGoal) }
                emptyHint("Целей пока нет. Можно копить с авто-пополнением.")
            }
        } else {
            GroupedSection("Цели", actionTitle: "Новая цель", action: { router.push(SavingsRoute.newGoal) }) {
                ForEach(store.goals) { goal in
                    GoalCard(goal: goal) { store.topUpGoal(id: goal.id, by: 5_000) }
                }
            }
        }
    }

    // MARK: Ruble deposits (insured, fixed rate)

    private var depositsSection: some View {
        GroupedSection("Вклады", footer: SavingsRisk.insuredASV.detail) {
            ForEach(SavingsCatalog.depositProducts) { product in
                DepositProductCard(
                    product: product,
                    apy: SavingsRates.depositApy(base: product.baseApy, tier: tier),
                    isPremium: isPremium
                ) { router.push(SavingsRoute.openDeposit(productId: product.id)) }
            }
        }
    }

    // MARK: Crypto staking (market risk, not insured)

    private var stakingSection: some View {
        GroupedSection("Стейкинг", footer: SavingsRisk.marketRisk.detail) {
            ForEach(SavingsCatalog.stakeProducts) { product in
                StakeProductCard(
                    product: product,
                    apy: SavingsRates.stakeApy(base: product.baseApy, tier: tier),
                    isPremium: isPremium,
                    unitPriceRub: store.price(for: product.asset)
                ) { router.push(SavingsRoute.stake(productId: product.id)) }
            }
        }
    }

    // MARK: Active вклады + стейки (Deposit contract)

    @ViewBuilder
    private var activeSection: some View {
        if store.deposits.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader("Мои вклады и стейки")
                emptyHint("Открытых вкладов и стейков пока нет")
            }
        } else {
            GroupedSection("Мои вклады и стейки") {
                ForEach(store.deposits) { dep in
                    ActiveSavingsRow(deposit: dep, valueRub: value(of: dep)) {
                        router.push(SavingsRoute.detail(depositId: dep.id))
                    }
                }
            }
        }
    }

    private func value(of dep: Deposit) -> Double {
        switch dep.kind {
        case .ruble: return dep.principal
        case .stake: return store.rubValue(units: dep.principal, asset: dep.asset ?? "")
        }
    }

    // MARK: Building blocks

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(BrandFont.subheadline)
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    NavigationStack {
        SavingsHubView()
    }
    .environment(AppSession.mockAuthenticated())
    .environment(\.apiClient, MockAPIClient())
    .environment(\.theme, .default)
    .environment(Router())
}
