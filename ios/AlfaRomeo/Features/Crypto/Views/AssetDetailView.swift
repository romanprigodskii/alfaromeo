import SwiftUI

/// Крипто-актив (детейл) (§9.6) in the dark «professional mode» (applied from ``CryptoRoute`` via
/// ``proTradingChrome()``): a live price header, the exchange-style ``TradingChartView`` (таймфреймы +
/// свечи + индикатор), the order book (``OrderBookView``), Купить/Продать (зелёная/красная,
/// compliance-gated to BTC/ETH + стейблы), asset info and the staking teaser. Non-tradable held assets
/// (SOL/TON) stay view-only: chart yes, order book / trading no — a soft compliance note instead (§2.4).
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
                holdingCard
                tradeActions
                infoCard
                stakingTeaser
            }
            .padding(.horizontal, Spacing.lg)
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
        HStack(spacing: Spacing.md) {
            AssetGlyph(symbol: symbol, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(asset?.name ?? symbol).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                Text("\(symbol) · \(asset?.chain ?? "")").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(amount: price, size: 22)
                if let change {
                    Text(CryptoFormat.pct(change))
                        .font(BrandFont.callout.weight(.semibold))
                        .foregroundStyle(change >= 0 ? theme.success : theme.danger)
                }
            }
        }
    }

    // MARK: Holding

    @ViewBuilder private var holdingCard: some View {
        if balance > 0 {
            SurfaceCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("В портфеле").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        Text(CryptoFormat.qty(balance, symbol: symbol)).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    }
                    Spacer()
                    AmountText(amount: balance * price, size: 20)
                }
            }
        }
    }

    // MARK: Trade actions (compliance-gated, green=buy / red=sell)

    @ViewBuilder private var tradeActions: some View {
        if tradable {
            HStack(spacing: Spacing.md) {
                TradeActionButton(title: "Купить", side: .buy, icon: "arrow.down.left") {
                    router.push(CryptoRoute.trade(symbol: symbol, side: .buy))
                }
                TradeActionButton(title: "Продать", side: .sell, icon: "arrow.up.right") {
                    router.push(CryptoRoute.trade(symbol: symbol, side: .sell))
                }
            }
            HStack(spacing: Spacing.md) {
                SecondaryButton(title: "Обмен", icon: "arrow.2.squarepath") { router.push(CryptoRoute.convert(asset: symbol)) }
                SecondaryButton(title: "Отправить", icon: "paperplane") { router.push(CryptoRoute.send(asset: symbol)) }
            }
        } else {
            SurfaceCard {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Торговля недоступна в РФ-режиме").font(BrandFont.callout.weight(.semibold)).foregroundStyle(theme.textPrimary)
                        Text("Доступны только BTC, ETH и стейблы (§2.4). \(symbol) можно держать и просматривать.")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: Info + staking

    private var infoCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Об активе").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                infoRow("Сеть", asset?.chain ?? symbol)
                Divider().overlay(theme.border)
                infoRow("Тип", (asset?.isStablecoin == true) ? "Стейблкоин" : "Криптовалюта")
                Divider().overlay(theme.border)
                infoRow("Курс (live)", CryptoFormat.rub(price))
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value).font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var stakingTeaser: some View {
        if let apy = model.stakingApy {
            Button { router.push(CryptoRoute.staking(symbol: symbol)) } label: {
                SurfaceCard {
                    HStack(spacing: Spacing.md) {
                        ZStack {
                            Circle().fill(theme.cryptoGradient).frame(width: 40, height: 40)
                            Image(systemName: "lock.circle.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Стейкинг \(symbol)").font(BrandFont.bodyM.weight(.semibold)).foregroundStyle(theme.textPrimary)
                            Text("До \(CryptoFormat.pct(apy, fraction: 1)) годовых · вклад нового поколения").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .buttonStyle(PressableButtonStyle())
        }
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
