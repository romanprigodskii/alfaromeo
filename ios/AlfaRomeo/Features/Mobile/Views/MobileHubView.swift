import SwiftUI

/// Ромео Mobile — мобильный хаб (§7.2, §9.7). Pushed onto the Home section ``Router`` via
/// `HomeRoute.mobile` → `MobileHubView()`; it registers every ``MobileRoute`` sub-flow on that same
/// stack (`.navigationDestination(for: MobileRoute.self)`) — the one-stack pattern the Crypto/Savings
/// hubs use. (A nested `NavigationStack` here renders blank, since the hub is itself a pushed
/// destination of the Home stack.)
///
/// Shows the active profile's остатки (ГБ/минуты via ``ProgressBar``), the tier-linked тариф, and
/// кэшбек гигабайтами. The tariff is **derived from the effective tier** (override → API), so it
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
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
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
        VStack(alignment: .leading, spacing: Spacing.lg) {
            DataBalanceCard(tariff: tariff, usedGb: plan.usedGb, usedMin: plan.usedMin,
                            bonusGb: store.bonusGb, msisdn: plan.msisdn,
                            roamingOn: store.roamingEnabled || tariff.isUnlimited)

            tariffLine

            CashbackGBCard(cashback: store.cashback(rate: tariff.cashbackGbPerMonth)) {
                store.creditCashbackToPackage()
            }

            actionsGrid

            if !store.payments.isEmpty { recentPayments }
        }
    }

    private var tariffLine: some View {
        Button { router.push(MobileRoute.tariffs) } label: {
            SurfaceCard(padding: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "simcard.fill").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Тариф \(tariff.name)").font(BrandFont.bodyM.weight(.medium))
                            .foregroundStyle(theme.textPrimary)
                        Text("В связке с классом \(effectiveTier.displayName) (§7.1)")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Text("Сменить").font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.accent)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var actionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.md),
                            GridItem(.flexible(), spacing: Spacing.md)], spacing: Spacing.md) {
            actionTile("eSIM и номера", "simcard", .esim)
            actionTile("Использование", "chart.bar.fill", .usage)
            actionTile("Роуминг", "airplane", .roaming)
            actionTile("Семейный пакет", "person.2.fill", .family)
            actionTile("Оплата связи", "creditcard.fill", .payment(.topUp))
            actionTile("Тарифы", "square.stack.3d.up.fill", .tariffs)
        }
    }

    private func actionTile(_ title: String, _ icon: String, _ route: MobileRoute) -> some View {
        Button { router.push(route) } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text(title).font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(theme.border, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var recentPayments: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Платежи связи").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    let shown = Array(store.payments.prefix(3))
                    ForEach(Array(shown.enumerated()), id: \.element.id) { i, p in
                        ListRow(icon: p.purpose.icon, title: p.purpose.title,
                                subtitle: p.sourceTitle + (p.isCrypto ? " · крипта" : ""),
                                value: "−\(Int(p.amount)) ₽")
                        if i < shown.count - 1 { Divider().overlay(theme.border) }
                    }
                }
            }
        }
    }

    // MARK: - Empty / loading / error

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Image(systemName: "simcard").font(.system(size: 28)).foregroundStyle(theme.accent)
                    Text("Подключите Ромео Mobile").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Text("eSIM активируется мгновенно: по QR, с новым номером или переносом своего (MNP). Тариф — в связке с вашим классом (§7.1).")
                        .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            PrimaryButton(title: "Подключить eSIM", icon: "plus") { router.push(MobileRoute.esim) }
            Button { router.push(MobileRoute.tariffs) } label: {
                Text("Посмотреть тарифы").font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private var loadingState: some View {
        VStack(spacing: Spacing.md) { ProgressView().controlSize(.large) }
            .frame(maxWidth: .infinity, minHeight: 240)
    }

    private var errorState: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Не удалось загрузить Ромео Mobile", systemImage: "exclamationmark.triangle")
                    .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("Проверьте соединение и попробуйте снова.")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                SecondaryButton(title: "Повторить", icon: "arrow.clockwise") {
                    Task { await store.load(api: api, profileId: profileId, force: true) }
                }
            }
        }
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
