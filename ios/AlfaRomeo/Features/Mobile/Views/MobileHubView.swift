import SwiftUI

/// Ромео Mobile — мобильный хаб (§7.2, §9.7). Pushed onto the Home section ``Router`` via
/// `HomeRoute.mobile` → `MobileHubView()`; it registers every ``MobileRoute`` sub-flow on that same
/// stack (`.navigationDestination(for: MobileRoute.self)`) — the one-stack pattern the Crypto/Savings
/// hubs use. (A nested `NavigationStack` here renders blank, since the hub is itself a pushed
/// destination of the Home stack.)
///
/// Shows the active profile's остатки (ГБ/минуты via ``ProgressBar``), a grouped list of sub-flows led
/// by the tier-linked тариф, and кэшбек гигабайтами. The tariff is **derived from the effective tier** (override → API), so it
/// always matches §7.1 — on Infinite it reads «Безлимит». Profiles without a plan get a «Подключить
/// eSIM» state that opens the connect wizard.
struct MobileHubView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = MobileStore.shared

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var effectiveTier: Tier { session.currentTier(for: profileId, fallback: store.baseTier) }
    private var tariff: MobileTariff { MobileTariff.make(for: effectiveTier) }

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .navigationTitle("Ромео Mobile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: MobileRoute.self) { $0.destination }
        .task(id: profileId) { await store.load(api: api, profileId: profileId) }
        .animation(reduceMotion ? nil : Motion.smooth, value: store.plan?.esimId)
        .animation(reduceMotion ? nil : Motion.snappy, value: effectiveTier)
    }

    @ViewBuilder
    private var content: some View {
        if store.loadFailed {
            errorState
        } else if let plan = store.plan {
            connected(plan)
        } else if store.didLoad {
            emptyState
        } else {
            loadingState
        }
    }

    // MARK: - Connected

    @ViewBuilder
    private func connected(_ plan: MobilePlan) -> some View {
        let roamingOn = store.roamingEnabled || tariff.isUnlimited
        VStack(alignment: .leading, spacing: Spacing.section) {
            DataBalanceCard(tariff: tariff, usedGb: plan.usedGb, usedMin: plan.usedMin,
                            bonusGb: store.bonusGb, msisdn: plan.msisdn,
                            roamingOn: roamingOn)

            GroupedSection {
                navRow("square.stack.3d.up", "Тариф", subtitle: "Класс \(effectiveTier.displayName)",
                       value: tariff.name, .tariffs)
                navRow("simcard", "eSIM и номера", .esim)
                navRow("chart.bar", "Использование", .usage)
                navRow("airplane", "Роуминг", .roaming)
                navRow("person.2", "Семейный пакет", value: familyCountLabel, .family)
                navRow("creditcard", "Оплата связи", .payment(.topUp))
            }

            CashbackGBCard(cashback: store.cashback(rate: tariff.cashbackGbPerMonth)) {
                store.creditCashbackToPackage()
            }

            if !store.payments.isEmpty { recentPayments }
        }
    }

    private var familyCountLabel: String? {
        let n = store.family.count
        guard n > 0 else { return nil }
        let (mod10, mod100) = (n % 10, n % 100)
        let word = mod10 == 1 && mod100 != 11 ? "участник"
            : (2...4).contains(mod10) && !(12...14).contains(mod100) ? "участника" : "участников"
        return MoneyFormat.integer(n) + "\u{00A0}" + word
    }

    private func navRow(_ icon: String, _ title: String, subtitle: String? = nil, value: String? = nil,
                        _ route: MobileRoute) -> some View {
        Button { router.push(route) } label: {
            ListRow(icon: icon, title: title, subtitle: subtitle, value: value, showsChevron: true)
        }
        .buttonStyle(.row)
    }

    private var recentPayments: some View {
        GroupedSection("Платежи связи") {
            ForEach(Array(store.payments.prefix(3))) { p in
                ListRow(icon: p.purpose.icon, title: p.purpose.title,
                        subtitle: p.sourceTitle,
                        value: MoneyFormat.fiat(-p.amount))
            }
        }
    }

    // MARK: - Empty / loading / error

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Ромео Mobile не подключён").font(BrandFont.title2).foregroundStyle(theme.textPrimary)
                Text("eSIM по QR, с новым номером или переносом своего (MNP). Тариф зависит от вашего класса.")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Подключить eSIM") { router.push(MobileRoute.esim) }
                TertiaryButton("Посмотреть тарифы") { router.push(MobileRoute.tariffs) }
            }
        }
        .padding(.top, Spacing.sm)
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            SkeletonRow(showsGlyph: false)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 160, alignment: .top)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            GroupedSection {
                ForEach(0..<4, id: \.self) { _ in SkeletonRow(showsSubtitle: false) }
            }
        }
        .accessibilityLabel("Загрузка")
    }

    private var errorState: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Не удалось загрузить Ромео Mobile")
                    .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("Проверьте соединение и попробуйте снова.")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            }
            SecondaryButton(title: "Повторить") {
                Task { await store.load(api: api, profileId: profileId, force: true) }
            }
        }
        .padding(.top, Spacing.sm)
    }
}

// MARK: - Previews

private struct MobileHubPreviewHost: View {
    let session: AppSession
    var body: some View {
        NavigationStack {
            MobileHubView()
        }
        .themeProvider(profileType: session.activeProfile?.type)
        .environment(session)
        .environment(Router())
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview("Хаб · Pro (Пакет M)") {
    MobileHubPreviewHost(session: .mockAuthenticated())
}

#Preview("Хаб · Infinite (Безлимит)") {
    let session = AppSession.mockAuthenticated()
    if let p = session.activeProfile { session.setTier(.infinite, for: p.id) }
    return MobileHubPreviewHost(session: session)
}
