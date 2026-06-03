import SwiftUI

/// Детейл одного счёта (§9.1, §10.2) — drill-down from the dashboard «Счета» block
/// (``HomeRoute.accountDetail``). One account in detail: its balance + currency (₽-эквивалент for the
/// crypto account via live prices), masked requisites with a show/hide «глаз», quick actions
/// (Пополнить / Перевести / Реквизиты), and the operations feed **scoped to this account** — the same
/// tx→account heuristic the История feed uses (``HistoryFilter.resolvedAccountId``), grouped by day
/// (``BudgetAnalytics.daySections``) and rendered with the shared ``TransactionRow``. Tapping an
/// operation opens the shared ``OperationDetailView``; the quick actions open the real
/// ``TransferFlowView`` — both reached by registering ``HistoryRoute`` / ``PaymentsRoute`` on this
/// (Home) stack, the same one-stack seam used by ``CryptoHubView`` / ``CreditView``.
///
/// All data is profile-scoped via the shared ``HistoryStore`` and reloads on profile switch (§5.3).
/// Named `…Screen` (not `AccountDetailView`) to avoid colliding with the business account detail.
struct AccountDetailScreen: View {
    let accountId: String

    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = HistoryStore.shared
    @State private var prices = LivePriceService.shared
    @State private var loaded = false
    @State private var revealNumber = false
    @State private var showRequisites = false

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var holderName: String { session.activeProfile?.displayName ?? "Владелец счёта" }
    private var account: Account? { store.accounts.first { $0.id == accountId } }

    /// Operations associated with this account by the shared heuristic — the same one the «Счета»
    /// filter uses, so the per-account feed and История agree (crypto trade/convert → крипто-счёт,
    /// остальное → текущий счёт).
    private var accountTransactions: [Transaction] {
        store.allTransactions.filter {
            HistoryFilter.resolvedAccountId(for: $0, in: store.accounts) == accountId
        }
    }
    private var reference: Date { store.referenceDate ?? Date() }
    private var sections: [DaySection] {
        BudgetAnalytics.daySections(accountTransactions, reference: reference)
    }

    var body: some View {
        ScrollView {
            content
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .navigationTitle(account?.displayTitle ?? "Счёт")
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : Motion.snappy, value: revealNumber)
        // Reuse История's operation detail + the Payments transfer wizard on this Home stack — same
        // seam pattern as CryptoHubView / CreditView / PaymentsView register their own destinations.
        .navigationDestination(for: HistoryRoute.self) { $0.destination }
        .navigationDestination(for: PaymentsRoute.self) { $0.destination }
        .sheet(isPresented: $showRequisites) {
            if let account {
                AccountRequisitesSheet(
                    requisites: AccountRequisites.make(for: account, holder: holderName),
                    accountTitle: account.displayTitle)
            }
        }
        // Crypto ₽-эквивалент + live-pill (idempotent; harmless for ₽ accounts).
        .task { await prices.start() }
        // Profile-scoped load; re-runs on account/profile change (§5.3).
        .task(id: "\(accountId)|\(profileId)") { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let account {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header(account)
                actionsRow(account)
                operationsSection
                statementButton
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if loaded {
            notFound
        } else {
            ProgressView().controlSize(.large).tint(theme.accent)
                .frame(maxWidth: .infinity).padding(.top, Spacing.xxl)
        }
    }

    // MARK: - Header

    private func header(_ account: Account) -> some View {
        SurfaceCard(elevated: true) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: account.type.paymentsIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(account.type == .crypto ? (theme.accentCrypto.first ?? theme.accent) : theme.accent)
                        .frame(width: 40, height: 40)
                        .background((account.type == .crypto ? (theme.accentCrypto.first ?? theme.accent) : theme.accent).opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.displayTitle.uppercased())
                            .font(BrandFont.micro.weight(.semibold)).tracking(1.1)
                            .foregroundStyle(theme.textSecondary)
                        Text(currencyName(account))
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                }

                AmountText(amount: account.balance, currency: account.symbol, size: 34)

                if account.type == .crypto {
                    HStack(spacing: Spacing.sm) {
                        Text("≈ \(CryptoFormat.rub(AccountValuation.rubValue(account, prices: prices)))")
                            .font(BrandFont.callout.weight(.medium))
                            .foregroundStyle(theme.textSecondary)
                            .monospacedDigit()
                        livePill
                    }
                }

                divider
                numberRow(account)
            }
        }
    }

    /// Masked account number / wallet address with a quick «глаз» reveal (full requisites live in the
    /// «Реквизиты» sheet).
    private func numberRow(_ account: Account) -> some View {
        let req = AccountRequisites.make(for: account, holder: holderName)
        let isCrypto = account.type == .crypto
        let label = isCrypto ? "Адрес" : "Номер счёта"
        let value = isCrypto
            ? (revealNumber ? req.address : req.addressMasked)
            : (revealNumber ? req.accountNumberFull : req.accountNumberMasked)
        return HStack(spacing: Spacing.sm) {
            Text(label).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(value)
                .font(BrandFont.mono(15, weight: .medium))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .contentTransition(.identity)
            Button { withAnimation(Motion.snappy) { revealNumber.toggle() } } label: {
                Image(systemName: revealNumber ? "eye.slash" : "eye")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(revealNumber ? "Скрыть номер" : "Показать номер")
        }
    }

    private var livePill: some View {
        HStack(spacing: Spacing.xxs) {
            Circle().fill(prices.isLive ? theme.success : theme.warning).frame(width: 6, height: 6)
            Text(prices.isLive ? "live-курс" : "оффлайн")
                .font(BrandFont.micro.weight(.medium)).foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Quick actions

    private func actionsRow(_ account: Account) -> some View {
        HStack(spacing: Spacing.sm) {
            ForEach(AccountQuickAction.actions(for: account.type)) { action in
                QuickActionTile(icon: action.icon, title: action.title) {
                    handle(action, account: account)
                }
            }
        }
    }

    private func handle(_ action: AccountQuickAction, account: Account) {
        switch action.kind {
        case .transfer(let kind): router.push(PaymentsRoute.transfer(kind))
        case .requisites:         showRequisites = true
        case .cryptoHub:          router.push(HomeRoute.crypto)
        }
    }

    // MARK: - Operations (per-account feed)

    @ViewBuilder
    private var operationsSection: some View {
        DashboardSection(title: "Операции") {
            if sections.isEmpty {
                emptyOps
            } else {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(sections) { daySection($0) }
                }
            }
        }
    }

    private func daySection(_ section: DaySection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Spacer()
                AmountText(amount: section.net, size: 13, showsSign: true, colorBySign: true)
                    .opacity(0.85)
            }
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(section.transactions.enumerated()), id: \.element.id) { index, tx in
                        Button {
                            router.push(HistoryRoute.operationDetail(txId: tx.id))
                        } label: {
                            TransactionRow(transaction: tx, category: store.category(for: tx))
                        }
                        .buttonStyle(.plain)
                        if index < section.transactions.count - 1 {
                            Divider().overlay(theme.border)
                        }
                    }
                }
            }
        }
    }

    private var emptyOps: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .light)).foregroundStyle(theme.textSecondary)
            Text("Пока нет операций")
                .font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
            Text("Операции по этому счёту появятся здесь.")
                .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Spacing.xl)
    }

    // MARK: - Statement / reports (облегчённый вход)

    private var statementButton: some View {
        SecondaryButton(title: "Выписка и отчёты", icon: "doc.text") {
            router.push(HistoryRoute.reports)
        }
    }

    // MARK: - States

    private var notFound: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 40, weight: .light)).foregroundStyle(theme.textSecondary)
            Text("Счёт не найден").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Text("Возможно, он относится к другому профилю.")
                .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.xxl).padding(Spacing.lg)
    }

    // MARK: - Helpers

    private var divider: some View { Divider().overlay(theme.border) }

    private func currencyName(_ account: Account) -> String {
        account.currency.uppercased() == "RUB" ? "Рубли · ₽" : account.currency.uppercased()
    }

    private func load() async {
        await store.load(api: api, profileId: profileId)
        loaded = true
    }
}

// MARK: - Previews

#Preview("Текущий счёт") {
    NavigationStack { AccountDetailScreen(accountId: "acc_cur") }
        .environment(AppSession.mockAuthenticated())
        .environment(Router())
        .environment(\.apiClient, MockAPIClient())
        .environment(\.theme, .default)
}

#Preview("Накопительный (пусто)") {
    NavigationStack { AccountDetailScreen(accountId: "acc_sav") }
        .environment(AppSession.mockAuthenticated())
        .environment(Router())
        .environment(\.apiClient, MockAPIClient())
        .environment(\.theme, .default)
}

#Preview("Крипто-счёт") {
    NavigationStack { AccountDetailScreen(accountId: "acc_cr") }
        .environment(AppSession.mockAuthenticated())
        .environment(Router())
        .environment(\.apiClient, MockAPIClient())
        .environment(\.theme, .default)
}
