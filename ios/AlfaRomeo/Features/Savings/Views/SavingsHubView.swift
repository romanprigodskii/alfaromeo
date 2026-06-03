import SwiftUI

/// «Приумножить» — the savings + staking hub (§10.6). Ruble deposits and crypto staking sit side by
/// side with an honest АСВ-vs-рыночный-риск contrast; APY is tier-boosted (§4, premium on Infinite);
/// goals show progress + auto-top-up; and the active list reflects the ``Deposit`` contract.
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
            VStack(spacing: Spacing.lg) {
                header
                goalsSection
                RiskComparisonStrip()
                depositsSection
                stakingSection
                activeSection
            }
            .padding(Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Приумножить")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: SavingsRoute.self) { $0.destination }
        .task(id: profileId) { await store.load(api: api, profileId: profileId) }
        .task { await store.streamPrices() }
    }

    // MARK: Header — total + tier (premium APY / upsell, §4)

    private var header: some View {
        SurfaceCard(elevated: true) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("В работе").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                AmountText(amount: store.totalValueRub, size: 32)
                    .contentTransition(.numericText())
                if isPremium {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "sparkles").foregroundStyle(theme.accent)
                        Text("Premium APY активен на тарифе \(tier.displayName)")
                            .font(BrandFont.caption).foregroundStyle(theme.textPrimary)
                    }
                } else {
                    UpsellCard(
                        title: "Премиальный APY на Infinite",
                        message: "Ставки по вкладам выше на +\(points(SavingsRates.depositUpliftToTop(from: tier))), APY стейкинга — до +\(points(SavingsRates.stakeUpliftToTop(from: tier))).",
                        recommendedTier: .infinite
                    )
                }
            }
        }
        .animation(Motion.snappy, value: store.totalValueRub)
    }

    // MARK: Goals (§10.6)

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Цели", action: ("Новая цель", { router.push(SavingsRoute.newGoal) }))
            if store.goals.isEmpty {
                emptyHint("Поставьте цель — поможем накопить с авто-пополнением.")
            } else {
                ForEach(store.goals) { goal in
                    GoalCard(goal: goal) { store.topUpGoal(id: goal.id, by: 5_000) }
                }
            }
        }
    }

    // MARK: Ruble deposits

    private var depositsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Рублёвые вклады", subtitle: "Застраховано АСВ · фиксированная ставка")
            ForEach(SavingsCatalog.depositProducts) { product in
                DepositProductCard(
                    product: product,
                    apy: SavingsRates.depositApy(base: product.baseApy, tier: tier),
                    isPremium: isPremium
                ) { router.push(SavingsRoute.openDeposit(productId: product.id)) }
            }
        }
    }

    // MARK: Crypto staking

    private var stakingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Крипто-стейкинг", subtitle: "Рыночный риск · не застраховано")
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

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Мои вклады и стейки")
            if store.deposits.isEmpty {
                emptyHint("Здесь появятся ваши открытые вклады и стейки.")
            } else {
                SurfaceCard(padding: Spacing.xs) {
                    VStack(spacing: 0) {
                        ForEach(store.deposits) { dep in
                            ActiveSavingsRow(deposit: dep, valueRub: value(of: dep)) {
                                router.push(SavingsRoute.detail(depositId: dep.id))
                            }
                            if dep.id != store.deposits.last?.id {
                                Divider().overlay(theme.border)
                            }
                        }
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

    @ViewBuilder
    private func sectionHeader(_ title: String, subtitle: String? = nil,
                               action: (String, () -> Void)? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                if let subtitle {
                    Text(subtitle).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
            }
            Spacer()
            if let action {
                Button(action: action.1) {
                    Text(action.0).font(BrandFont.callout.weight(.semibold)).foregroundStyle(theme.accent)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.top, Spacing.xs)
    }

    private func emptyHint(_ text: String) -> some View {
        SurfaceCard {
            Text(text).font(BrandFont.body()).foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func points(_ value: Double) -> String { String(format: "%.1f п.п.", value) }
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
