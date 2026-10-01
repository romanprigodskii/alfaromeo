import SwiftUI

/// «Дашборд» — the business-mode home (§8.2, §9.9). Root of the **Дашборд** tab. An assembly of the
/// pieces other business modules already own — it deliberately holds **no** data of its own:
///  • **AI-инсайт** строкой → the AI-бухгалтер's cash-gap headline → opens the Чаты(AI) tab.
///  • **Баланс по счетам** → ``BusinessAccountsStore`` (the very figures the Счета tab shows, treasury
///    valued at the **live** rate) → opens the Счета tab.
///  • **Кэшфлоу** → reuses ``CashflowForecastCard`` (the 90-day Swift Charts projection from the
///    AI-бухгалтер), grounded in the shared ``BusinessCashflowMock`` scenario.
///  • **Задачи · на подпись** → ``TeamStore.pendingApprovalItems`` — the **same** 2-of-N ``ApprovalRequest``
///    заявки as the Команда tab (not a copy); each opens ``ApprovalDetailView`` to sign with biometrics.
///
/// Cross-tab destinations are tab switches via `onSelectTab` (wired by ``BusinessTabView``); the only
/// in-stack push is the approval detail. Runs in the graphite business theme (§8/§13.1).
struct BusinessDashboardView: View {
    /// Switch the business tab bar (AI-инсайт → Чаты, баланс → Счета, «Все» задачи → Команда). Defaults
    /// to a no-op so previews / the screenshot harness can host the root standalone.
    var onSelectTab: (BusinessTab) -> Void = { _ in }

    @Environment(Router.self) private var router
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var accounts = BusinessAccountsStore.shared
    @State private var team = TeamStore.shared
    @State private var prices = LivePriceService.shared
    @State private var scenario = BusinessCashflowMock.scenario()

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var currentUserId: String { session.currentUser?.id ?? "u_demo" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                aiInsight
                balanceCard
                CashflowForecastCard(scenario: scenario)
                tasksSection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .navigationTitle("Дашборд")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: DashboardRoute.self) { $0.destination }
        .task(id: profileId) {
            await accounts.load(api: api, profileId: profileId)
            await team.load(api: api, profileId: profileId, currentUserId: currentUserId)
        }
        .task { await prices.start() }
        .task { await FXRateService.shared.start() }
    }

    // MARK: AI-инсайт строкой

    private var aiInsight: some View {
        let copy = insightCopy
        return DashboardAIInsightCard(title: copy.title, message: copy.message, cta: copy.cta) {
            onSelectTab(.chats)
        }
    }

    private var insightCopy: (title: String, message: String, cta: String) {
        if let gap = scenario.gap {
            return ("Кассовый разрыв \(BizFormat.inDays(gap.inDays))",
                    "Прогноз: дефицит ликвидности ~\(BizFormat.compactRuble(gap.amount)) к \(BizFormat.dayMonth(gap.date)). Спросите AI-бухгалтера, как его закрыть.",
                    "Открыть AI-бухгалтера")
        } else {
            return ("Денежный поток в норме",
                    "По 90-дневному прогнозу кассового разрыва нет. Минимальный остаток \(BizFormat.compactRuble(scenario.minBalance)).",
                    "Спросить AI-бухгалтера")
        }
    }

    // MARK: Баланс по счетам

    @ViewBuilder private var balanceCard: some View {
        if accounts.loadFailed {
            // Don't present a false «₽0 / 0 счетов» hero on a failed load — mirror the Счета error path
            // with a compact retry (the store commits `loadedProfileId` only on success, so this retries).
            SurfaceCard(elevated: true) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(theme.warning)
                    Text("Не удалось загрузить баланс по счетам")
                        .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    Spacer(minLength: Spacing.sm)
                    Button("Повторить") {
                        Task { await accounts.load(api: api, profileId: profileId, force: true) }
                    }
                    .font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.accent)
                }
            }
        } else if accounts.didLoad {
            AccountBalanceHero(totalRub: accounts.totalRub, isLive: prices.isLive,
                               subline: balanceSubline, actionTitle: "Открыть счета") {
                onSelectTab(.accounts)
            }
        } else {
            SurfaceCard(elevated: true) {
                HStack { ProgressView().tint(theme.accent); Spacer() }
                    .frame(minHeight: 96)
            }
        }
    }

    private var balanceSubline: String {
        var parts = [BizFormat.accounts(accounts.accountCount)]
        if accounts.treasuryRub > 0 {
            parts.append("трежери \(CryptoFormat.compactRub(accounts.treasuryRub)) по live-курсу")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Задачи · на подпись + счета на оплату

    private var tasksSection: some View {
        let pending = team.pendingApprovalItems
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Задачи · на подпись", badge: pending.isEmpty ? nil : pending.count,
                          actionTitle: pending.isEmpty ? nil : "Все") { onSelectTab(.team) }

            if pending.isEmpty {
                SurfaceCard {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(theme.isDark ? theme.success : BrandColors.successInkLight)
                        Text("Нет платежей, ожидающих подписи.")
                            .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    }
                }
            } else {
                ForEach(pending.prefix(2)) { item in
                    Button { router.push(DashboardRoute.approval(approvalId: item.id)) } label: {
                        ApprovalCard(item: item)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            invoicesRow
        }
    }

    /// «Счета на оплату» (§8.2 задачи) — the AI-бухгалтер's unpaid-invoices count; opens the AI tab,
    /// which tracks неоплаченные счета and cashflow.
    @ViewBuilder private var invoicesRow: some View {
        if scenario.unpaidInvoicesCount > 0 {
            Button { onSelectTab(.chats) } label: {
                SurfaceCard(padding: Spacing.md) {
                    ListRow(icon: "doc.text.magnifyingglass", iconTint: theme.warning,
                            title: "Счета на оплату",
                            subtitle: "\(scenario.unpaidInvoicesCount) неоплаченных · \(BizFormat.compactRuble(scenario.unpaidInvoicesTotal))",
                            showsChevron: true)
                }
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: Helpers

    private func sectionHeader(_ title: String, badge: Int? = nil,
                               actionTitle: String?, action: @escaping () -> Void) -> some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                if let badge { Badge(kind: .count(badge), tint: theme.accent) }
            }
            Spacer()
            if let actionTitle {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    }
                    .font(BrandFont.caption.weight(.semibold))
                    .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview

private struct BusinessDashboardPreviewHost: View {
    var body: some View {
        let session = AppSession.mockAuthenticated()
        if let biz = session.profiles.first(where: { $0.type == .business }) {
            session.switchProfile(biz)
        }
        return NavigationStack {
            BusinessDashboardView()
                .navigationDestination(for: DashboardRoute.self) { $0.destination }
        }
        .themeProvider(profileType: .business)
        .environment(session)
        .environment(Router())
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview("Дашборд · бизнес") { BusinessDashboardPreviewHost() }
