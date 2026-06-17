import Foundation

/// A tradable crypto asset and its compliance status (§2.4). The demo's tradable set is
/// **BTC / ETH / TON + стейблы (USDT, USDC)**. SOL is *priced* (live) and *held* (bank legacy /
/// external wallets) but is not offered for new trades — the asset detail surfaces that as a soft
/// compliance note, not a dead end.
struct CryptoAsset: Identifiable, Hashable, Sendable {
    let symbol: String          // BTC, ETH, USDT, …
    let name: String            // Bitcoin, Ethereum, …
    let chain: String           // native chain label
    let isStablecoin: Bool
    /// Allowed for new buy/sell/convert under the RF demo regime (§2.4).
    let tradable: Bool

    var id: String { symbol }
}

/// The canonical crypto registry the hub draws on. Prices come from ``LivePriceService`` (BTC/ETH/
/// USDT/SOL/TON are backend-tracked; USDC is priced 1:1 against USDT, both ≈ $1).
enum CryptoCatalog {

    static let all: [CryptoAsset] = [
        CryptoAsset(symbol: "BTC",  name: "Bitcoin",   chain: "Bitcoin",  isStablecoin: false, tradable: true),
        CryptoAsset(symbol: "ETH",  name: "Ethereum",  chain: "Ethereum", isStablecoin: false, tradable: true),
        CryptoAsset(symbol: "USDT", name: "Tether",    chain: "Tron",     isStablecoin: true,  tradable: true),
        CryptoAsset(symbol: "USDC", name: "USD Coin",  chain: "Ethereum", isStablecoin: true,  tradable: true),
        CryptoAsset(symbol: "SOL",  name: "Solana",    chain: "Solana",   isStablecoin: false, tradable: false),
        CryptoAsset(symbol: "TON",  name: "Toncoin",   chain: "TON",      isStablecoin: false, tradable: true),
    ]

    /// Assets we subscribe to for live ₽ pricing (backend-tracked symbols).
    static let pricedSymbols = ["BTC", "ETH", "USDT", "SOL", "TON"]

    /// The compliant set offered for new trades / buys (§2.4).
    static var tradable: [CryptoAsset] { all.filter(\.tradable) }
    static var stablecoins: [CryptoAsset] { all.filter(\.isStablecoin) }

    static func asset(_ symbol: String) -> CryptoAsset? {
        all.first { $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame }
    }

    static func name(_ symbol: String) -> String { asset(symbol)?.name ?? symbol }
    static func isTradable(_ symbol: String) -> Bool { asset(symbol)?.tradable ?? false }
    static func isStable(_ symbol: String) -> Bool { asset(symbol)?.isStablecoin ?? false }

    /// Anonymous / privacy coins barred for licensed venues (§2.4) — used in the compliance note.
    static let bannedAnonymous = ["XMR", "ZEC", "DASH"]
    static let complianceNote =
        "Доступны BTC, ETH, TON и стейблкоины (USDT/USDC). Анонимные монеты (Monero, Zcash) запрещены для лицензированных площадок."

    // MARK: - Networks (send / receive)

    /// Settlement networks offered for an asset, with a mock network-fee preview (₽) and ETA. The
    /// ERC-20 option is flagged `congested` to drive the «сеть перегружена» edge case (§10.8).
    static func networks(for symbol: String) -> [CryptoNetwork] {
        switch symbol.uppercased() {
        case "BTC":
            return [CryptoNetwork(id: "btc", name: "Bitcoin", feeRub: 240, estMinutes: 20)]
        case "ETH":
            return [CryptoNetwork(id: "erc20", name: "Ethereum · ERC-20", feeRub: 560, estMinutes: 3, congested: true)]
        case "USDT":
            return [
                CryptoNetwork(id: "trc20", name: "Tron · TRC-20", feeRub: 90, estMinutes: 2),
                CryptoNetwork(id: "erc20", name: "Ethereum · ERC-20", feeRub: 560, estMinutes: 4, congested: true),
                CryptoNetwork(id: "ton",   name: "TON", feeRub: 12, estMinutes: 1),
            ]
        case "USDC":
            return [
                CryptoNetwork(id: "erc20", name: "Ethereum · ERC-20", feeRub: 560, estMinutes: 4, congested: true),
                CryptoNetwork(id: "trc20", name: "Tron · TRC-20", feeRub: 90, estMinutes: 2),
            ]
        case "SOL":
            return [CryptoNetwork(id: "sol", name: "Solana", feeRub: 14, estMinutes: 1)]
        case "TON":
            return [CryptoNetwork(id: "ton", name: "TON", feeRub: 12, estMinutes: 1)]
        default:
            return [CryptoNetwork(id: "native", name: chainLabel(symbol), feeRub: 100, estMinutes: 5)]
        }
    }

    static func chainLabel(_ symbol: String) -> String { asset(symbol)?.chain ?? symbol }
}

/// A settlement network for crypto send/receive, with a mock fee preview (§10.8 «превью комиссии сети»).
struct CryptoNetwork: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let feeRub: Double
    let estMinutes: Int
    var congested: Bool = false

    var etaLabel: String { estMinutes <= 1 ? "≈ 1 мин" : "≈ \(estMinutes) мин" }
}
