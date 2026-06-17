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
        // The whole crypto module is light, like the rest of the app (§9.6): every screen just uses the
        // ambient DesignSystem `\.theme` — no per-route chrome. (The exchange was briefly a dark «проф-
        // режим»; that decision was reverted.)
        case .assetDetail(let symbol):      AssetDetailView(symbol: symbol)
        case .trade(let symbol, let side, let price):
            TradeOrderView(symbol: symbol, side: side, prefilledPrice: price)
        case .tradeHistory:                 TradeHistoryView()
        case .investorStatus:               InvestorStatusView()
        case .cfaDetail(let id):            CDFADetailView(cdfaId: id)
        case .linkExternalWallet:           ExternalWalletLinkView()
        case .convert(let asset):           ConvertView(asset: asset)
        case .send(let asset):              SendCryptoView(asset: asset)
        case .receive(let asset):           ReceiveCryptoView(asset: asset)
        case .staking(let symbol):          StakeFlowView(symbol: symbol)
        }
    }
}
