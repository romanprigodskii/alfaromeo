import SwiftUI

/// Крипто/Трейдинг хаб (§9.6). One unified ₽ portfolio over **bank crypto + ЦФА + watch-only external
/// wallets**, valued on real live prices via ``LivePriceService`` (our backend → a public exchange
/// directly → demo walk; the hero badge names the active source). The narrative split is two
/// segments under one header: **Крипта** (под приходящий режим, с комплаенс-гейтингом) and **ЦФА**
/// (259-ФЗ — легальный путь, без крипто-лимитов).
/// A ₽/$ denomination toggle on the hero re-expresses the whole portfolio (display-only).
///
/// Reached two ways — as the **Биржа** tab root (``MainTabView``, wrapped by ``SectionScaffold``) or
/// pushed as `HomeRoute.crypto` from the dashboard. It is light like the rest of the app (no special
/// chrome — just the ambient DesignSystem `\.theme`) and registers the crypto routes on the active
/// section stack, so every sub-screen pushes via that section's ``Router`` (see ``CryptoRoute``).
struct CryptoHubView: View {
    @Environment(Router.self) private var router
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var store = CryptoStore.shared
    @State private var prices = LivePriceService.shared
    @State private var segment: PortfolioSegment = .crypto
    /// ₽/$ display toggle for the whole portfolio (§9.6). Local to the hub — display-only.
    @State private var denomination: PortfolioDenomination = .rub

    init(segment: PortfolioSegment = .crypto) {
        _segment = State(initialValue: segment)
    }

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var investorStatus: InvestorStatus { session.currentUser?.investorStatus ?? .unqualified }
    private var defaultAsset: String { store.bankWallets.first?.asset ?? "BTC" }
    /// Buy/convert must target a tradable asset (§2.4: BTC/ETH/TON + стейблы) — never SOL.
    private var tradableDefault: String {
        store.bankWallets.first(where: { CryptoCatalog.isTradable($0.asset) })?.asset ?? "BTC"
    }
    private var summary: PortfolioSummary { store.summary(using: prices) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                PortfolioHeroCard(summary: summary, source: prices.source, isStale: prices.isStale,
                                  denomination: $denomination, usdRub: prices.usdRub)
                quickActions
                segmentPicker
                switch segment {
                case .crypto: cryptoSection
                case .cfa:    cfaSection
                case .stocks: MoexStocksSection()
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .navigationTitle("Крипто и ЦФА")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CryptoRoute.self) { $0.destination }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { router.push(CryptoRoute.tradeHistory) } label: { Label("История сделок", systemImage: "clock.arrow.circlepath") }
                    Button { router.push(CryptoRoute.investorStatus) } label: { Label("Статус инвестора", systemImage: "checkmark.shield") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task(id: profileId) { await store.load(api: api, profileId: profileId) }
        .task { await prices.start() }
    }

    // MARK: Quick actions

    private var quickActions: some View {
        QuickActionRow {
            QuickActionButton("Купить", systemImage: "plus") { router.push(CryptoRoute.trade(symbol: tradableDefault, side: .buy)) }
            QuickActionButton("Обмен", systemImage: "arrow.left.arrow.right") { router.push(CryptoRoute.convert(asset: tradableDefault)) }
            QuickActionButton("Отправить", systemImage: "arrow.up") { router.push(CryptoRoute.send(asset: defaultAsset)) }
            QuickActionButton("Принять", systemImage: "qrcode") { router.push(CryptoRoute.receive(asset: defaultAsset)) }
        }
    }

    private var segmentPicker: some View {
        Picker("Раздел", selection: $segment) {
            ForEach(PortfolioSegment.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    // MARK: Крипта

    @ViewBuilder private var cryptoSection: some View {
        if !store.didLoad {
            loading
        } else {
            let bank = store.cryptoPositions(using: prices).filter { !$0.watchOnly }

            GroupedSection("Мои монеты") {
                ForEach(bank) { position in
                    PositionRow(position: position, denomination: denomination, usdRub: prices.usdRub) {
                        router.push(CryptoRoute.assetDetail(symbol: position.routeId))
                    }
                }
                if bank.isEmpty {
                    emptyRow("Нет монет. Купите BTC, ETH или стейблкоин.")
                }
            }

            GroupedSection("Внешние кошельки", actionTitle: "Привязать",
                           action: { router.push(CryptoRoute.linkExternalWallet) }) {
                ForEach(store.externalWallets) { wallet in
                    ExternalWalletRow(wallet: wallet, valueRub: externalValue(wallet),
                                      denomination: denomination, usdRub: prices.usdRub) {
                        withAnimation { store.unlinkExternalWallet(id: wallet.id) }
                    }
                }
                if store.externalWallets.isEmpty {
                    emptyRow("MetaMask, Trust, Ledger или TON: баланс появится здесь в режиме просмотра.")
                }
            }

            GroupedSection("Ограничения") {
                if investorStatus == .unqualified { investorLimitRow }
                Text(CryptoCatalog.complianceNote)
                    .font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Spacing.rowVertical)
                Button { router.push(CryptoRoute.investorStatus) } label: {
                    ListRow(icon: "checkmark.shield", title: "Статус инвестора и лимиты", showsChevron: true)
                }
                .buttonStyle(.row)
            }
        }
    }

    /// Неквал limit usage (§2.4): used / yearly cap with a flat progress bar. Opens the status screen.
    private var investorLimitRow: some View {
        Button { router.push(CryptoRoute.investorStatus) } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Text("Лимит неквал-инвестора").font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    Spacer(minLength: Spacing.sm)
                    if !store.riskTestPassed {
                        StatusPill(status: .warning, text: "Тест не пройден")
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                }
                ProgressBar(value: store.investorUsedRub / CryptoCompliance.yearlyLimitRub)
                Text("\(CryptoFormat.rub(store.investorUsedRub)) из \(CryptoFormat.rub(CryptoCompliance.yearlyLimitRub)) в год")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
            }
            .padding(.vertical, Spacing.rowVertical)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
    }

    // MARK: ЦФА

    @ViewBuilder private var cfaSection: some View {
        let holdings = store.cfaPositions()
        VStack(alignment: .leading, spacing: Spacing.sm) {
            LegalBadge()
            Text("Токенизированные инструменты эмитентов через операторов из реестра ЦБ. Без крипто-лимитов и теста на риски, только обычный KYC.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if !holdings.isEmpty {
            GroupedSection("Мои ЦФА") {
                ForEach(holdings) { position in
                    PositionRow(position: position, denomination: denomination, usdRub: prices.usdRub) {
                        router.push(CryptoRoute.cfaDetail(id: position.routeId))
                    }
                }
            }
        }

        GroupedSection("Каталог ЦФА") {
            ForEach(MockCryptoData.cdfas) { cdfa in
                CDFACard(cdfa: cdfa, holdingUnits: store.cfaUnits(cdfaId: cdfa.id)) {
                    router.push(CryptoRoute.cfaDetail(id: cdfa.id))
                }
            }
        }
    }

    // MARK: Helpers

    private var loading: some View {
        GroupedSection {
            SkeletonRow()
            SkeletonRow()
            SkeletonRow()
        }
        .accessibilityLabel("Загружаем портфель")
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.rowVertical)
    }

    private func externalValue(_ wallet: ExternalWallet) -> Double {
        wallet.holdings.reduce(0) { $0 + prices.rubValue(asset: $1.asset, qty: $1.balance) }
    }
}

#Preview {
    NavigationStack {
        CryptoHubView()
            .environment(AppSession.mockAuthenticated())
            .environment(Router())
            .environment(\.apiClient, MockAPIClient())
            .environment(\.theme, .default)
    }
}
