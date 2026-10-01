import SwiftUI

/// «Дашборд» — the business-mode home (§8.2, §9.9). Root of the **Дашборд** tab. An assembly of the
/// pieces other business modules already own — it deliberately holds **no** data of its own:
///  • **Баланс по счетам** → ``BusinessAccountsStore`` (the very figures the Счета tab shows, treasury
///    valued at the **live** rate) → opens the Счета tab.
///  • **AI-инсайт** строкой → the AI-бухгалтер's cash-gap headline → opens the Чаты(AI) tab.
///  • **Кэшфлоу** → reuses ``CashflowForecastCard`` (the 90-day Swift Charts projection from the
///    AI-бухгалтер), grounded in the shared ``BusinessCashflowMock`` scenario.
///  • **Задачи** (на подпись) → ``TeamStore.pendingApprovalItems`` — the **same** 2-of-N ``ApprovalRequest``
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
            VStack(alignment: .leading, spacing: Spacing.section) {
                balanceBlock
                aiInsight
                CashflowForecastCard(scenario: scenario)
                tasksSection
            }
            .padding(.horizontal, Spacing.screen)
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
        return DashboardAIInsightCard(title: copy.title, message: copy.message, cta: "Спросить") {
            onSelectTab(.chats)
        }
    }

    private var insightCopy: (title: String, message: String) {
        if let gap = scenario.gap {
            return ("Кассовый разрыв \(BizFormat.inDays(gap.inDays))",
                    "Дефицит около \(BizFormat.compactRuble(gap.amount)) к \(BizFormat.dayMonth(gap.date)).")
        } else {
            return ("Денежный поток в норме",
                    "Разрыва в 90-дневном прогнозе нет. Минимальный остаток \(BizFormat.compactRuble(scenario.minBalance)).")
        }
    }

    // MARK: Баланс по счетам

    @ViewBuilder private var balanceBlock: some View {
        if accounts.loadFailed {
            // Don't present a false «₽0 / 0 счетов» hero on a failed load: mirror the Счета error path
            // with a compact retry (the store commits `loadedProfileId` only on success, so this retries).
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text("Не удалось загрузить баланс по счетам")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                Spacer(minLength: Spacing.sm)
                Button("Повторить") {
                    Task { await accounts.load(api: api, profileId: profileId, force: true) }
                }
                .font(BrandFont.body(15, weight: .medium)).foregroundStyle(theme.accent)
                .buttonStyle(.plain)
            }
        } else if accounts.didLoad {
            AccountBalanceHero(totalRub: accounts.totalRub, isLive: prices.isLive,
                               footnote: balanceFootnote) {
                onSelectTab(.accounts)
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                RoundedRectangle(cornerRadius: 4).fill(theme.fill).frame(width: 140, height: 14)
                RoundedRectangle(cornerRadius: 6).fill(theme.fill).frame(width: 220, height: 40)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .accessibilityLabel("Загружаем баланс")
        }
    }

    private var balanceFootnote: String {
        var parts = [BizFormat.accounts(accounts.accountCount)]
        if accounts.treasuryRub > 0 {
            parts.append("трежери \(MoneyFormat.compact(accounts.treasuryRub)) по live-курсу")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Задачи: на подпись + счета на оплату

    private var tasksSection: some View {
        let pending = team.pendingApprovalItems
        return GroupedSection("Задачи",
                              actionTitle: pending.isEmpty ? nil : "Все",
                              action: { onSelectTab(.team) }) {
            if pending.isEmpty {
                ListRow(icon: "checkmark.seal", title: "Нет платежей на подпись")
            } else {
                ForEach(pending.prefix(2)) { item in
                    Button { router.push(DashboardRoute.approval(approvalId: item.id)) } label: {
                        ApprovalRow(item: item)
                    }
                    .buttonStyle(.row)
                }
            }
            invoicesRow
        }
    }

    /// «Счета на оплату» (§8.2 задачи): the AI-бухгалтер's unpaid-invoices count; opens the AI tab,
    /// which tracks неоплаченные счета and cashflow.
    @ViewBuilder private var invoicesRow: some View {
        if scenario.unpaidInvoicesCount > 0 {
            Button { onSelectTab(.chats) } label: {
                ListRow(icon: "doc.text",
                        title: "Счета на оплату",
                        subtitle: "\(scenario.unpaidInvoicesCount) неоплаченных",
                        value: BizFormat.compactRuble(scenario.unpaidInvoicesTotal),
                        showsChevron: true)
            }
            .buttonStyle(.row)
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
