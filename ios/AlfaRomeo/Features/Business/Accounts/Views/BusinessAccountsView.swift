import SwiftUI

/// «Счета/РКО» — the business-mode accounts hub (§8.2, §9.9). Root of the **Счета** tab; it registers
/// every ``AccountsRoute`` on the tab's own `NavigationStack` (the self-contained one-stack pattern of
/// the Acquiring/Team hubs), so sub-screens push without touching the shell.
///
/// Surfaces: a total-balance hero (₽ + multicurrency + crypto-treasury, all at the **live** rate), the
/// РКО accounts grouped into рублёвые / мультивалютные / крипто-трежери, and the entry into the
/// «выписка». Crypto-treasury (USDT/USDC) is valued by the same ``LivePriceService`` the Crypto Hub uses
/// (§2.4). Runs in the graphite business theme resolved by the profile (§8/§13.1).
struct BusinessAccountsView: View {
    @Environment(Router.self) private var router
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var store = BusinessAccountsStore.shared
    @State private var prices = LivePriceService.shared

    private var profileId: String { session.activeProfile?.id ?? "" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if store.loadFailed {
                    errorBlock
                } else if !store.didLoad {
                    loadingBlock
                } else {
                    hero
                    ForEach(store.populatedGroups) { group in
                        groupSection(group)
                    }
                    statementsEntry
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .navigationTitle("Счета")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: AccountsRoute.self) { $0.destination }
        .task(id: profileId) { await store.load(api: api, profileId: profileId) }
        .task { await prices.start() }
    }

    // MARK: Hero

    private var hero: some View {
        AccountBalanceHero(totalRub: store.totalRub, isLive: prices.isLive, subline: heroSubline)
    }

    private var heroSubline: String {
        var parts = ["Расчётный \(CryptoFormat.compactRub(store.settlementRub))"]
        if store.multicurrencyRub > 0 { parts.append("валюта \(CryptoFormat.compactRub(store.multicurrencyRub))") }
        if store.treasuryRub > 0 {
            // Stablecoins are $-pegged, so the native total reads as «$…» rather than mislabelling the
            // USDT+USDC sum as a single currency.
            parts.append("трежери $\(CryptoFormat.qty(store.treasuryStableTotal)) ≈ \(CryptoFormat.compactRub(store.treasuryRub))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Groups

    private func groupSection(_ group: BusinessAccountGroup) -> some View {
        let items = store.items(in: group)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 1) {
                Text(group.title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text(group.caption).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            }
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().overlay(theme.border) }
                        Button { router.push(AccountsRoute.accountDetail(accountId: item.id)) } label: {
                            AccountRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Statements

    private var statementsEntry: some View {
        Button { router.push(AccountsRoute.statements) } label: {
            SurfaceCard(padding: Spacing.md) {
                ListRow(icon: "doc.text", title: "Выписки",
                        subtitle: "Операции по счетам · экспорт PDF / CSV", showsChevron: true)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: States

    private var loadingBlock: some View {
        VStack(spacing: Spacing.md) {
            ProgressView().tint(theme.accent)
            Text("Загружаем счета…").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private var errorBlock: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(theme.warning)
                    Text("Не удалось загрузить счета").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                }
                Text("Проверьте соединение и попробуйте ещё раз.")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                SecondaryButton(title: "Повторить", icon: "arrow.clockwise") {
                    Task { await store.load(api: api, profileId: profileId, force: true) }
                }
            }
        }
    }
}

// MARK: - Preview

private struct BusinessAccountsPreviewHost: View {
    var body: some View {
        let session = AppSession.mockAuthenticated()
        if let biz = session.profiles.first(where: { $0.type == .business }) {
            session.switchProfile(biz)
        }
        return NavigationStack {
            BusinessAccountsView()
                .navigationDestination(for: AccountsRoute.self) { $0.destination }
        }
        .themeProvider(profileType: .business)
        .environment(session)
        .environment(Router())
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview("Счета · бизнес") { BusinessAccountsPreviewHost() }
