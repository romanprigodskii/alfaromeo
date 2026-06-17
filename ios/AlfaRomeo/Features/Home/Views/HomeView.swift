import SwiftUI

/// Главный — the personal dashboard (§9.1, §10.2).
///
/// An AI-insight line, the unified ₽-equivalent, then product blocks (Карты / Счета / Крипто /
/// Вклады / Кредиты), offer carousels, the Ромео Mobile teaser and «На карте» — all on the active
/// profile's mock data, reloaded whenever the profile changes (`.task(id:)`, §5.3). Cards open their
/// detail via the cross-module ``CardsRoute`` (§6.3); crypto / deposits / credits / mobile open
/// ``HomeRoute`` stubs. States: skeletons (loading), onboarding (empty profile), cache + banner
/// (refresh error) — §10.2.
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(ShellState.self) private var shell
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var model = HomeViewModel()

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        // Reserve room so the floating AI-copilot button never occludes the last block.
        .contentMargins(.bottom, 96, for: .scrollContent)
        .refreshable { await model.load(api: api, session: session) }
        // Reload scoped to the active profile — switching re-runs this under the new profileId (§5.3).
        .task(id: session.activeProfile?.id) { await model.load(api: api, session: session) }
        // Live crypto ticks for the view's lifetime (§11.4).
        .task { await model.streamPrices() }
        // Section-owned routes (§9.1).
        .navigationDestination(for: HomeRoute.self) { $0.destination }
        // Cross-module: cards are surfaced here but owned by the Cards module (§6.3, prompt 1.2).
        .navigationDestination(for: CardsRoute.self) { $0.destination }
    }

    @ViewBuilder
    private var content: some View {
        if model.isInitialLoading {
            HomeSkeleton()
        } else if let dashboard = model.dashboard {
            if dashboard.isEmpty {
                HomeEmptyState(
                    onOpenCard: { router.push(CardsRoute.order) },
                    onOpenWallet: { router.push(HomeRoute.crypto) }
                )
            } else {
                loaded(dashboard)
            }
        } else {
            HomeErrorCard { Task { await model.load(api: api, session: session) } }
        }
    }

    @ViewBuilder
    private func loaded(_ dashboard: HomeDashboard) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if model.refreshFailed {
                RefreshErrorBanner { Task { await model.load(api: api, session: session) } }
            }

            // AI-инсайт — точка входа в копилот как «поиск-и-действие» (§9.1 / §10.9): открываем
            // живой ``CopilotChatView`` поверх любого экрана через shell, а не отдельный экран поиска.
            AIInsightBar(dashboard: dashboard, live: model.livePrices) {
                shell.showCopilot(.search)
            }

            BalanceHero(dashboard: dashboard, live: model.livePrices)

            CardsCarousel(
                cards: dashboard.cards,
                onTapCard: { router.push(CardsRoute.detail(cardId: $0.id)) },
                onOrder: { router.push(CardsRoute.order) },
                onSeeAll: { router.push(CardsRoute.list) }
            )

            AccountsBlock(accounts: dashboard.accounts) {
                router.push(HomeRoute.accountDetail(accountId: $0.id))
            }

            if !dashboard.wallets.isEmpty {
                CryptoWalletBlock(dashboard: dashboard, live: model.livePrices) {
                    router.push(HomeRoute.crypto)
                }
            }

            if !dashboard.deposits.isEmpty {
                SavingsBlock(dashboard: dashboard) { router.push(HomeRoute.deposits) }
            }

            if let credit = dashboard.preApprovedCredit {
                CreditsBlock(amount: credit) { router.push(HomeRoute.credits) }
            }

            OffersCarousel { router.push(HomeRoute.openProduct) }

            // Выгода и кэшбек (§9.3) — moved off the personal tab bar («Биржа» took its slot) to this
            // dashboard block. Opens the unchanged BenefitsView (все 3 экрана) via HomeRoute.benefits.
            Button { router.push(HomeRoute.benefits) } label: {
                SurfaceCard(padding: Spacing.sm) {
                    ListRow(icon: "percent", title: "Выгода и кэшбек",
                            subtitle: "Кэшбек, категории, партнёры и подписка", showsChevron: true)
                }
            }
            .buttonStyle(.plain)

            if let plan = dashboard.mobilePlan {
                MobileBlock(plan: plan) { router.push(HomeRoute.mobile) }
            }

            // «На карте» (отделения/банкоматы, §9.1) скрыто в демо — реальной карты отделений нет,
            // честнее не показывать пустышку. Продуктовое решение, не баг. Компонент BranchesRow и
            // маршрут HomeRoute.branches остаются в коде для будущих фаз.
            // BranchesRow { router.push(HomeRoute.branches) }
        }
        .animation(reduceMotion ? nil : Motion.smooth, value: dashboard.profileId)
    }
}

// MARK: - Previews

/// Hosts ``HomeView`` with the same environment the shell injects (Router + AppSession + APIClient +
/// theme) so the dashboard renders on mock data without the auth flow. Two profiles show the
/// per-profile reload (§5.3): personal is rich; child is lean (no crypto / deposits / mobile).
private struct HomePreviewHost: View {
    let session: AppSession
    var body: some View {
        NavigationStack {
            HomeView().navigationTitle("Главный")
        }
        .themeProvider(profileType: session.activeProfile?.type)
        .environment(session)
        .environment(Router())
        .environment(ShellState())
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview("Личный профиль") {
    HomePreviewHost(session: .mockAuthenticated())
}
