import SwiftUI

/// Детейл одного счёта (§9.1, §10.2): drill-down from the dashboard «Счета» block
/// (``HomeRoute.accountDetail``). One account in detail: its balance + currency (₽-эквивалент for the
/// crypto account via live prices), quick actions (Пополнить / Перевести / Реквизиты), the masked
/// number with a show/hide «глаз», and the operations feed **scoped to this account**: the same
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
    @State private var fx = FXRateService.shared
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
        .task { await fx.start() }
        // Profile-scoped load; re-runs on account/profile change (§5.3).
        .task(id: "\(accountId)|\(profileId)") { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let account {
            VStack(alignment: .leading, spacing: Spacing.section) {
                header(account)
                actionsRow(account)
                GroupedSection {
                    numberRow(account)
                    statementRow
                }
                operationsSection
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: ListRow.glyphSpacing) {
                glyph(account)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayTitle)
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Text(currencyName(account))
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                AmountText(amount: account.balance, currency: account.symbol, size: 40, splitsKopecks: true)

                if account.type == .crypto {
                    HStack(spacing: Spacing.sm) {
                        Text("≈ \(MoneyFormat.fiat(AccountValuation.rubValue(account, prices: prices).rounded()))")
                            .font(BrandFont.subheadline)
                            .foregroundStyle(theme.textSecondary)
                            .monospacedDigit()
                        livePill
                    }
                } else if AccountValuation.isForeignFiat(account.currency) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("≈ \(MoneyFormat.fiat(AccountValuation.rubValue(account, prices: prices).rounded()))")
                            .font(BrandFont.subheadline)
                            .foregroundStyle(theme.textSecondary)
                            .monospacedDigit()
                        fxPill(account.currency)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Currency mark for fiat (₽ $ €, Ц for digital ₽); the real coin logo for the crypto account.
    @ViewBuilder
    private func glyph(_ account: Account) -> some View {
        if account.type == .crypto {
            CoinLogo(symbol: account.currency, size: ListRow.glyphSize)
        } else {
            GlyphCircle(currency: account.type == .digitalRuble ? "DRUB" : account.currency,
                        size: ListRow.glyphSize)
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
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                Text(value)
                    .font(BrandFont.code(16))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .contentTransition(.identity)
            }
            Spacer(minLength: Spacing.sm)
            Button { withAnimation(Motion.snappy) { revealNumber.toggle() } } label: {
                Image(systemName: revealNumber ? "eye.slash" : "eye")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(revealNumber ? "Скрыть номер" : "Показать номер")
        }
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
    }

    private var livePill: some View {
        HStack(spacing: Spacing.xxs) {
            Circle().fill(prices.isLive ? theme.success : theme.warning).frame(width: 6, height: 6)
            Text(prices.isLive ? "live-курс" : "офлайн")
                .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
        }
    }

    /// «1 USD = 83,25 ₽ · ▼ 0,38 %» over «курс ЦБ на dd.MM»; the dot is green once fetched live.
    private func fxPill(_ currency: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text([fx.rateText(currency), fx.changeText(currency)].compactMap { $0 }.joined(separator: " · "))
                .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                .monospacedDigit()
            HStack(spacing: Spacing.xxs + 2) {
                Circle().fill(fx.isLive ? theme.success : theme.warning).frame(width: 6, height: 6)
                Text(fx.label)
                    .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Quick actions

    private func actionsRow(_ account: Account) -> some View {
        QuickActionRow {
            ForEach(AccountQuickAction.actions(for: account.type)) { action in
                QuickActionButton(action.title, systemImage: action.icon) {
                    handle(action, account: account)
                }
            }
        }
    }

    private func handle(_ action: AccountQuickAction, account: Account) {
        switch action.kind {
        case .transfer(let kind): router.push(PaymentsRoute.transfer(kind))
        case .topUp:              router.push(PaymentsRoute.topUp(accountId: account.id))
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
                Text(section.title)
                    .font(BrandFont.body(15, weight: .semibold)).foregroundStyle(theme.textSecondary)
                Spacer()
                AmountText(amount: section.net, size: 15, showsSign: true, colorBySign: true)
            }
            .padding(.horizontal, Spacing.md)
            GroupedSection {
                ForEach(section.transactions) { tx in
                    Button {
                        router.push(HistoryRoute.operationDetail(txId: tx.id))
                    } label: {
                        TransactionRow(transaction: tx, category: store.category(for: tx))
                    }
                    .buttonStyle(.row)
                }
            }
        }
    }

    private var emptyOps: some View {
        VStack(spacing: Spacing.xs) {
            Text("Операций пока нет")
                .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
            Text("Здесь появятся операции по этому счёту.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Spacing.xl)
    }

    // MARK: - Statement / reports (облегчённый вход)

    private var statementRow: some View {
        Button { router.push(HistoryRoute.reports) } label: {
            ListRow(icon: "doc.text", title: "Выписка и отчёты", showsChevron: true)
        }
        .buttonStyle(.row)
    }

    // MARK: - States

    private var notFound: some View {
        VStack(spacing: Spacing.xs) {
            Text("Счёт не найден").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Text("Возможно, он относится к другому профилю.")
                .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, Spacing.xxl).padding(.horizontal, Spacing.screen)
    }

    // MARK: - Helpers

    private func currencyName(_ account: Account) -> String {
        let code = account.currency.uppercased()
        if code == "RUB" { return "Рубли · ₽" }
        if AccountValuation.isForeignFiat(code), let name = fx.quote(code)?.name { return "\(name) · \(code)" }
        return code
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
