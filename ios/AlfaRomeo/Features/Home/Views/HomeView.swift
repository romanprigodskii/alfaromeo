import SwiftUI

/// Главная: the personal dashboard (§9.1, §10.2).
///
/// The unified ₽-equivalent with a one-line AI hint, then product blocks (Карты / Счета / Крипто /
/// Вклады), «Сервисы» (кредит, выгода, Ромео Mobile) and offers, all on the active profile's data,
/// reloaded whenever the profile changes (`.task(id:)`, §5.3). Cards open their detail via the
/// cross-module ``CardsRoute`` (§6.3); the rest push ``HomeRoute``. States: skeletons (loading),
/// onboarding (empty profile), cache + banner (refresh error), §10.2. Layout per DESIGN §4: 16pt
/// margins, 28pt between sections, grouped lists instead of cards.
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
                .padding(.horizontal, Spacing.screen)
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
        VStack(alignment: .leading, spacing: Spacing.section) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if model.refreshFailed {
                    RefreshErrorBanner { Task { await model.load(api: api, session: session) } }
                }

                BalanceHero(dashboard: dashboard, live: model.livePrices)

                // AI-подсказка: точка входа в копилот как «поиск-и-действие» (§9.1 / §10.9). Открываем
                // живой ``CopilotChatView`` поверх любого экрана через shell, а не отдельный экран поиска.
                AIInsightBar(dashboard: dashboard, live: model.livePrices) {
                    shell.showCopilot(.search)
                }
            }

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

            // Кредит (§10.5), Выгода и кэшбек (§9.3, moved here off the tab bar) and Ромео Mobile (§9.7).
            ServicesBlock(
                preApprovedCredit: dashboard.preApprovedCredit,
                mobilePlan: dashboard.mobilePlan,
                onCredit: { router.push(HomeRoute.credits) },
                onBenefits: { router.push(HomeRoute.benefits) },
                onMobile: { router.push(HomeRoute.mobile) }
            )

            OffersBlock { router.push(HomeRoute.openProduct) }

            // «На карте» (отделения/банкоматы, §9.1) скрыто в демо: реальной карты отделений нет,
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
            HomeView().navigationTitle("Главная")
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
