import SwiftUI

/// Крипто-актив (детейл) (§9.6), light like the rest of the app: a live price header, the
/// exchange-style ``TradingChartView`` (таймфреймы + свечи + индикатор), the order book
/// (``OrderBookView``), Купить/Продать (зелёная/красная, compliance-gated to BTC/ETH/TON + стейблы),
/// holding + staking entry and asset info as grouped lists. Non-tradable held assets (SOL) stay
/// view-only: chart yes, order book / trading no, with a soft compliance note (§2.4).
struct AssetDetailView: View {
    let symbol: String

    @Environment(Router.self) private var router
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var model: AssetDetailModel
    @State private var prices = LivePriceService.shared
    @State private var store = CryptoStore.shared

    init(symbol: String) {
        self.symbol = symbol.uppercased()
        _model = State(initialValue: AssetDetailModel(symbol: symbol.uppercased()))
    }

    private var asset: CryptoAsset? { model.asset }
    private var price: Double { prices.price(symbol) }
    private var change: Double? { prices.change24h(symbol) }
    private var balance: Double { store.bankBalance(asset: symbol) }
    private var tradable: Bool { asset?.tradable == true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                TradingChartView(symbol: symbol, model: model)
                if tradable {
                    OrderBookView(symbol: symbol) { tappedPrice, side in
                        router.push(CryptoRoute.trade(symbol: symbol, side: side, price: tappedPrice))
                    }
                }
                tradeActions
                holdingSection
                PriceAlertsSection(asset: symbol, market: .crypto, assetTitle: asset?.name ?? symbol,
                                   currentPrice: price, isLive: prices.isLive)
                infoSection
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .navigationTitle(asset?.name ?? symbol)
        .navigationBarTitleDisplayMode(.inline)
        .task { await LivePriceService.shared.start() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            AssetGlyph(symbol: symbol, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(asset?.name ?? symbol).font(BrandFont.title2).foregroundStyle(theme.textPrimary)
                Text("\(symbol), \(asset?.chain ?? "")").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                PriceSourceBadge(source: prices.source, isStale: prices.isStale)
                    .padding(.top, 2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(amount: price, size: 22)
                if let change {
                    Text(CryptoFormat.pct(change))
                        .font(BrandFont.subheadline)
                        .foregroundStyle(change >= 0 ? theme.success : theme.danger)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: Trade actions (compliance-gated, green=buy / red=sell)

    @ViewBuilder private var tradeActions: some View {
        if tradable {
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    TradeActionButton(title: "Купить", side: .buy) {
                        router.push(CryptoRoute.trade(symbol: symbol, side: .buy))
                    }
                    TradeActionButton(title: "Продать", side: .sell) {
                        router.push(CryptoRoute.trade(symbol: symbol, side: .sell))
                    }
                }
                HStack(spacing: Spacing.sm) {
                    SecondaryButton(title: "Обмен") { router.push(CryptoRoute.convert(asset: symbol)) }
                    SecondaryButton(title: "Отправить") { router.push(CryptoRoute.send(asset: symbol)) }
                }
            }
        } else {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(theme.statusInk(.warning))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Торговля недоступна в РФ-режиме").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Text("Доступны BTC, ETH, TON и стейблкоины. \(symbol) можно держать и просматривать.")
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Holding + staking

    @ViewBuilder private var holdingSection: some View {
        if balance > 0 || model.stakingApy != nil {
            GroupedSection {
                if balance > 0 {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("В портфеле").font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                            Text(CryptoFormat.qty(balance, symbol: symbol))
                                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary).monospacedDigit()
                        }
                        Spacer()
                        AmountText(amount: balance * price, size: 17)
                    }
                    .padding(.vertical, Spacing.rowVertical)
                }
                if let apy = model.stakingApy {
                    Button { router.push(CryptoRoute.staking(symbol: symbol)) } label: {
                        ListRow(icon: "lock", title: "Стейкинг \(symbol)",
                                subtitle: "До \(MoneyFormat.percent(apy, maxFractionDigits: 1)) годовых",
                                showsChevron: true)
                    }
                    .buttonStyle(.row)
                }
            }
        }
    }

    // MARK: Info

    private var infoSection: some View {
        GroupedSection("Об активе") {
            infoRow("Сеть", asset?.chain ?? symbol)
            infoRow("Тип", (asset?.isStablecoin == true) ? "Стейблкоин" : "Криптовалюта")
            infoRow(prices.isLive ? "Курс (live)" : "Курс (демо)", CryptoFormat.rub(price))
            infoRow("Источник цены", prices.source.detail)
            if case .exchange = prices.source, let fx = prices.fx {
                infoRow(fxLabel(fx), CryptoFormat.rub(fx.usdRub, fraction: 2))
            }
        }
    }

    /// «Курс ЦБ на 02.10»: names the rate's origin so the ₽ conversion is auditable.
    private func fxLabel(_ fx: FxRateClient.Rate) -> String {
        let origin: String
        switch fx.origin {
        case .cbr:      origin = "Курс ЦБ $"
        case .market:   origin = "Рыночный курс USDT"
        case .cached:   origin = "Курс ЦБ $ (сохр.)"
        case .fallback: origin = "Курс $ (оценка)"
        }
        guard let date = fx.asOf, fx.origin != .market else { return origin }
        return "\(origin) на \(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits)))"
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(BrandFont.bodyM).foregroundStyle(theme.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(value).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Spacing.rowVertical)
    }
}

#Preview {
    NavigationStack {
        AssetDetailView(symbol: "BTC")
            .environment(Router())
            .environment(\.apiClient, MockAPIClient())
            .environment(\.theme, .resolve(for: nil, scheme: .dark))
    }
}
