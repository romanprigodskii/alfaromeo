import SwiftUI

/// «Счета/РКО» — the business-mode accounts hub (§8.2, §9.9). Root of the **Счета** tab; it registers
/// every ``AccountsRoute`` on the tab's own `NavigationStack` (the self-contained one-stack pattern of
/// the Acquiring/Team hubs), so sub-screens push without touching the shell.
///
/// Surfaces: a total-balance hero (₽ + multicurrency at курс ЦБ + crypto-treasury at the live rate),
/// the РКО accounts grouped into рублёвые / валютные / крипто-трежери, and the entry into the «выписка». Crypto-treasury (USDT/USDC) is valued by the same ``LivePriceService`` the Crypto Hub uses
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
            VStack(alignment: .leading, spacing: Spacing.section) {
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
            .padding(.horizontal, Spacing.screen)
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
        .task { await FXRateService.shared.start() }
    }

    // MARK: Hero

    private var hero: some View {
        AccountBalanceHero(totalRub: store.totalRub, isLive: prices.isLive,
                           stats: heroStats, footnote: heroFootnote)
    }

    private var heroStats: [AccountBalanceHero.Stat] {
        var stats = [AccountBalanceHero.Stat(label: "Расчётный", value: MoneyFormat.compact(store.settlementRub))]
        if store.multicurrencyRub > 0 {
            stats.append(.init(label: "Валюта", value: MoneyFormat.compact(store.multicurrencyRub)))
        }
        if store.treasuryRub > 0 {
            stats.append(.init(label: "Трежери", value: MoneyFormat.compact(store.treasuryRub)))
        }
        return stats
    }

    private var heroFootnote: String? {
        var lines: [String] = []
        if store.multicurrencyRub > 0 {
            lines.append("Валюта в ₽ · \(FXRateService.shared.label)")
        }
        if store.treasuryRub > 0 {
            // Stablecoins are $-pegged, so the native total reads as «$…» rather than mislabelling the
            // USDT+USDC sum as a single currency.
            lines.append("Трежери \(MoneyFormat.fiat(store.treasuryStableTotal, currency: "$")) · live-курс")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    // MARK: Groups

    private func groupSection(_ group: BusinessAccountGroup) -> some View {
        GroupedSection(group.title, footer: group.caption) {
            ForEach(store.items(in: group)) { item in
                Button { router.push(AccountsRoute.accountDetail(accountId: item.id)) } label: {
                    AccountRow(item: item)
                }
                .buttonStyle(.row)
            }
        }
    }

    // MARK: Statements

    private var statementsEntry: some View {
        GroupedSection("Документы") {
            Button { router.push(AccountsRoute.statements) } label: {
                ListRow(icon: "doc.text", title: "Выписки",
                        subtitle: "Все счета, PDF и CSV", showsChevron: true)
            }
            .buttonStyle(.row)
        }
    }

    // MARK: States

    private var loadingBlock: some View {
        GroupedSection {
            ForEach(0..<3, id: \.self) { _ in SkeletonRow() }
        }
        .accessibilityLabel("Загружаем счета")
    }

    private var errorBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Не удалось загрузить счета").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("Проверьте соединение и попробуйте ещё раз.")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            }
            SecondaryButton(title: "Повторить") {
                Task { await store.load(api: api, profileId: profileId, force: true) }
            }
        }
        .padding(.top, Spacing.md)
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
