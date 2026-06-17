import SwiftUI

/// Крипто/Трейдинг хаб (§9.6). One unified ₽ portfolio over **bank crypto + ЦФА + watch-only external
/// wallets**, valued on real live prices (REST snapshot + ``PriceSocket`` stream via
/// ``LivePriceService``). The narrative split is two segments under one header: **Крипта** (под
/// приходящий режим, с комплаенс-гейтингом) and **ЦФА** (259-ФЗ — легальный путь, без крипто-лимитов).
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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                PortfolioHeroCard(summary: summary, isLive: prices.isLive,
                                  denomination: $denomination, usdRub: prices.usdRub)
                quickActions
                segmentPicker
                if segment == .crypto { cryptoSection } else { cfaSection }
            }
            .padding(.horizontal, Spacing.lg)
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
        HStack(spacing: Spacing.sm) {
            action("Купить", "cart.fill") { router.push(CryptoRoute.trade(symbol: tradableDefault, side: .buy)) }
            action("Обмен", "arrow.2.squarepath") { router.push(CryptoRoute.convert(asset: tradableDefault)) }
            action("Отправить", "paperplane.fill") { router.push(CryptoRoute.send(asset: defaultAsset)) }
            action("Принять", "qrcode") { router.push(CryptoRoute.receive(asset: defaultAsset)) }
        }
    }

    private func action(_ title: String, _ icon: String, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            VStack(spacing: Spacing.xs) {
                ZStack {
                    Circle().fill(theme.cryptoGradient).frame(width: 48, height: 48)
                    Image(systemName: icon).font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                }
                Text(title).font(BrandFont.micro.weight(.medium)).foregroundStyle(theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var segmentPicker: some View {
        VStack(spacing: Spacing.sm) {
            Picker("", selection: $segment) {
                ForEach(PortfolioSegment.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(segment.caption).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Крипта

    @ViewBuilder private var cryptoSection: some View {
        if !store.didLoad {
            loading
        } else {
            let bank = store.cryptoPositions(using: prices).filter { !$0.watchOnly }

            if investorStatus == .unqualified { investorLimitStrip }

            sectionHeader("Мои монеты", actionTitle: nil) {}
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(bank.enumerated()), id: \.element.id) { index, position in
                        if index > 0 { Divider().overlay(theme.border) }
                        PositionRow(position: position, denomination: denomination, usdRub: prices.usdRub) {
                            router.push(CryptoRoute.assetDetail(symbol: position.routeId))
                        }
                    }
                    if bank.isEmpty {
                        Text("Нет монет. Купите BTC, ETH или стейблкоин.")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, Spacing.sm)
                    }
                }
            }

            sectionHeader("Внешние кошельки", actionTitle: "Привязать") { router.push(CryptoRoute.linkExternalWallet) }
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(store.externalWallets.enumerated()), id: \.element.id) { index, wallet in
                        if index > 0 { Divider().overlay(theme.border) }
                        ExternalWalletRow(wallet: wallet, valueRub: externalValue(wallet),
                                          denomination: denomination, usdRub: prices.usdRub) {
                            withAnimation { store.unlinkExternalWallet(id: wallet.id) }
                        }
                    }
                    if store.externalWallets.isEmpty {
                        Text("Привяжите MetaMask, Trust, Ledger или TON — баланс появится здесь read-only.")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, Spacing.sm)
                    }
                }
            }

            ComplianceBanner { router.push(CryptoRoute.investorStatus) }
        }
    }

    private var investorLimitStrip: some View {
        Button { router.push(CryptoRoute.investorStatus) } label: {
            SurfaceCard(padding: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text("Лимит неквал-инвестора").font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.textPrimary)
                        Spacer()
                        if !store.riskTestPassed {
                            Text("Тест не пройден").font(BrandFont.micro.weight(.semibold)).foregroundStyle(theme.warning)
                        }
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(theme.textSecondary)
                    }
                    ProgressBar(value: store.investorUsedRub / CryptoCompliance.yearlyLimitRub, useCryptoGradient: true)
                    Text("Использовано \(CryptoFormat.rub(store.investorUsedRub)) из \(CryptoFormat.rub(CryptoCompliance.yearlyLimitRub)) в год")
                        .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: ЦФА

    @ViewBuilder private var cfaSection: some View {
        let holdings = store.cfaPositions()
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack { LegalBadge(); Spacer() }
            Text("Легальный путь цифровых активов: токенизированные инструменты от эмитентов через операторов в реестре ЦБ. Без крипто-лимитов и теста — только обычный KYC.")
                .font(BrandFont.caption).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
        }

        if !holdings.isEmpty {
            sectionHeader("Мои ЦФА", actionTitle: nil) {}
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(holdings.enumerated()), id: \.element.id) { index, position in
                        if index > 0 { Divider().overlay(theme.border) }
                        PositionRow(position: position, denomination: denomination, usdRub: prices.usdRub) {
                            router.push(CryptoRoute.cfaDetail(id: position.routeId))
                        }
                    }
                }
            }
        }

        sectionHeader("Каталог ЦФА", actionTitle: nil) {}
        VStack(spacing: Spacing.md) {
            ForEach(MockCryptoData.cdfas) { cdfa in
                CDFACard(cdfa: cdfa, holdingUnits: store.cfaUnits(cdfaId: cdfa.id)) {
                    router.push(CryptoRoute.cfaDetail(id: cdfa.id))
                }
            }
        }
    }

    // MARK: Helpers

    private var loading: some View {
        VStack(spacing: Spacing.md) {
            ProgressView().tint(theme.accentCrypto.first ?? theme.accent)
            Text("Загружаем портфель…").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func sectionHeader(_ title: String, actionTitle: String?, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Spacer()
            if let actionTitle {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionTitle); Image(systemName: "plus.circle.fill").font(.system(size: 12, weight: .semibold))
                    }
                    .font(BrandFont.caption.weight(.semibold))
                    .foregroundStyle(theme.accentCrypto.first ?? theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
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
