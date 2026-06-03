import SwiftUI

/// Navigation routes owned by the Crypto hub (§9.6). Pushed onto the Home section ``Router`` and
/// resolved by ``CryptoHubView`` via `.navigationDestination(for: CryptoRoute.self)` — the same
/// per-tab coordinator the Home stack already provides (the hub itself is `HomeRoute.crypto`).
enum CryptoRoute: Hashable {
    case assetDetail(symbol: String)        // крипто-актив (детейл): график, Купить/Продать, стейкинг
    case cfaDetail(id: String)              // 🆕 ЦФА (детейл): эмитент/оператор, доходность
    case convert(asset: String?)            // 🆕 конвертация крипто↔₽ / ↔стейбл
    case trade(symbol: String, side: CryptoSide, price: Double? = nil)  // трейдинг/ордер: маркет/лимит (price → предзаполненный лимит из стакана)
    case send(asset: String?)               // отправить: контакт/адрес/QR + сеть
    case receive(asset: String?)            // принять: адрес/QR/запрос
    case linkExternalWallet                 // 🆕 привязка внешнего кошелька (watch-only)
    case staking(symbol: String)            // стейкинг — вход из детейла (полная реализация 2.2)
    case investorStatus                     // статус инвестора / лимиты / тест (крипта)
    case tradeHistory                       // история сделок
}

extension CryptoRoute {
    @ViewBuilder var destination: some View {
        switch self {
        // The whole hub is now dark «проф-режим» (§13.1: биржа целиком тёмная). The hub itself gets
        // `.cryptoHubChrome()` at its entry points (the «Биржа» tab root + `HomeRoute.crypto`), so these
        // pushed children inherit dark `\.theme`. Chrome is (re)applied here, from outside each view, so
        // each screen's own `@Environment(\.theme)` resolves correctly:
        //
        // • DARK — the exchange surfaces you stay *inside* (актив / ордер / история сделок / статус
        //   инвестора / ЦФА / привязка кошелька). `.cryptoHubChrome()`/`.proTradingChrome()` are the same
        //   dark chrome; both pin it so the screen is dark regardless of how it was reached.
        // • LIGHT — the money-movement flows that leave the exchange feel (Обмен / Отправить / Принять)
        //   and the cross-module стейкинг (→ Savings). These MUST `.cryptoLightChrome()`: it resets
        //   `\.theme` back to light *and* reclaims a light window, so the dark never leaks and the app is
        //   light again on pop. (Resetting only `.preferredColorScheme(.light)` would leave a dark theme.)
        case .assetDetail(let symbol):      AssetDetailView(symbol: symbol).proTradingChrome()
        case .trade(let symbol, let side, let price):
            TradeOrderView(symbol: symbol, side: side, prefilledPrice: price).proTradingChrome()
        case .tradeHistory:                 TradeHistoryView().cryptoHubChrome()
        case .investorStatus:               InvestorStatusView().cryptoHubChrome()
        case .cfaDetail(let id):            CDFADetailView(cdfaId: id).cryptoHubChrome()
        case .linkExternalWallet:           ExternalWalletLinkView().cryptoHubChrome()
        case .convert(let asset):           ConvertView(asset: asset).cryptoLightChrome()
        case .send(let asset):              SendCryptoView(asset: asset).cryptoLightChrome()
        case .receive(let asset):           ReceiveCryptoView(asset: asset).cryptoLightChrome()
        case .staking(let symbol):          StakeFlowView(symbol: symbol).cryptoLightChrome()
        }
    }
}
