import Foundation
import Observation

/// One activity entry in the crypto/ЦФА «История сделок» (§9.6). Covers trades, converts, sends,
/// receives and ЦФА purchases — a unified feed the trade-history screen renders.
enum CryptoActivityKind: String, Hashable, Sendable {
    case buy, sell, convert, send, receive, cfaBuy, stake

    var label: String {
        switch self {
        case .buy:     return "Покупка"
        case .sell:    return "Продажа"
        case .convert: return "Конвертация"
        case .send:    return "Отправка"
        case .receive: return "Получение"
        case .cfaBuy:  return "Покупка ЦФА"
        case .stake:   return "Стейкинг"
        }
    }

    var icon: String {
        switch self {
        case .buy:     return "arrow.down.left.circle.fill"
        case .sell:    return "arrow.up.right.circle.fill"
        case .convert: return "arrow.2.squarepath"
        case .send:    return "paperplane.fill"
        case .receive: return "tray.and.arrow.down.fill"
        case .cfaBuy:  return "building.columns.fill"
        case .stake:   return "lock.circle.fill"
        }
    }

    /// Inflow (+ green) vs outflow.
    var isInflow: Bool { self == .buy || self == .receive }
}

struct CryptoActivity: Identifiable, Hashable, Sendable {
    let id: String
    let kind: CryptoActivityKind
    let title: String
    let subtitle: String
    let asset: String
    let qty: Double
    let rubAmount: Double      // signed ₽ value (+ inflow / − outflow)
    let at: Date
}

/// Shared, in-memory state for the whole Crypto hub (§9.6). Mirrors the ``CardsStore`` rationale: the
/// API is read-only fixtures, route destinations are independent views pushed on the Home stack, and
/// there is no mutation endpoint — so a `@MainActor @Observable` singleton lets a buy in the trade
/// flow, a ЦФА purchase, a linked wallet, and a passed risk test all reflect live in the dashboard.
/// Every mutation is a demo simulation against the **live** prices from ``LivePriceService`` (§11.4/§14).
@MainActor
@Observable
final class CryptoStore {
    static let shared = CryptoStore()

    private(set) var bankWallets: [CryptoWallet] = []
    private(set) var cfaHoldings: [CDFAHolding] = []
    private(set) var externalWallets: [ExternalWallet] = []
    private(set) var orders: [Order] = []
    private(set) var activity: [CryptoActivity] = []

    /// Неквал-инвестор: ₽ used against the 300к/year ceiling (§2.4). Grows as crypto trades settle.
    private(set) var investorUsedRub: Double = CryptoCompliance.seededUsedRub
    /// The «тест на риски» gate (§10.8). Crypto only — ЦФА never checks this.
    private(set) var riskTestPassed = false

    private(set) var didLoad = false
    private(set) var loadFailed = false

    private var loadedProfileId: String?
    private var profileId = ""
    private var seq = 0

    private init() {}

    // MARK: - Load (once per profile)

    func load(api: any APIClient, profileId: String, force: Bool = false) async {
        guard !profileId.isEmpty, force || loadedProfileId != profileId else { return }
        self.profileId = profileId
        do {
            let wallets = try await api.cryptoWallets(profileId: profileId)
            async let ordersR = (try? await api.orders(profileId: profileId)) ?? []
            // Real crypto holdings live on the backend (``WalletService``): once registered, the portfolio
            // shows the server's balances (so different phones differ), not the local mock wallets.
            if WalletService.shared.registered {
                await WalletService.shared.refreshBalance()
                bankWallets = Self.serverWallets(profileId: profileId)
            } else {
                bankWallets = wallets
            }
            orders = await ordersR
            // Seed the feature-local (no-backend) state per profile.
            cfaHoldings = MockCryptoData.seededCDFAHoldings
            externalWallets = MockCryptoData.seededExternalWallets
            investorUsedRub = CryptoCompliance.seededUsedRub
            activity = Self.seedActivity(orders: orders, profileId: profileId)
            loadFailed = false
            didLoad = true
            loadedProfileId = profileId
        } catch {
            loadFailed = true
            didLoad = true
        }
    }

    // MARK: - Lookups

    func bankWallet(asset: String) -> CryptoWallet? {
        bankWallets.first { $0.asset.caseInsensitiveCompare(asset) == .orderedSame }
    }
    func bankBalance(asset: String) -> Double { bankWallet(asset: asset)?.balance ?? 0 }

    /// Rebuild the bank wallets from the live server holdings (``WalletService``) — call after a crypto
    /// transfer so the portfolio reflects the move immediately.
    func reloadServerBalances() async {
        await WalletService.shared.refreshBalance()
        if WalletService.shared.registered { bankWallets = Self.serverWallets(profileId: profileId) }
    }

    /// One ``CryptoWallet`` per server-tracked asset, valued from ``WalletService`` (a demo address keyed
    /// to the phone). Zero-balance assets are kept out of the portfolio by the existing `balance > 0` filter.
    private static func serverWallets(profileId: String) -> [CryptoWallet] {
        let w = WalletService.shared
        let tail = String((w.phone ?? "").filter(\.isNumber).suffix(4))
        let meta: [(asset: String, chain: String, prefix: String)] = [
            ("BTC", "bitcoin", "bc1q"), ("ETH", "ethereum", "0x"), ("USDT", "tron", "TQ"), ("TON", "ton", "EQ"),
        ]
        return meta.map { m in
            CryptoWallet(id: "w_\(m.asset.lowercased())", profileId: profileId, asset: m.asset, chain: m.chain,
                         address: "\(m.prefix)…\(tail)", balance: w.cryptoBalance(m.asset))
        }
    }
    func cfaHolding(cdfaId: String) -> CDFAHolding? { cfaHoldings.first { $0.cdfaId == cdfaId } }
    func cfaUnits(cdfaId: String) -> Double { cfaHolding(cdfaId: cdfaId)?.units ?? 0 }

    // MARK: - Compliance gate (crypto only)

    func requiresRiskTest(investorStatus: InvestorStatus) -> Bool {
        investorStatus == .unqualified && !riskTestPassed
    }
    var investorRemainingRub: Double { max(0, CryptoCompliance.yearlyLimitRub - investorUsedRub) }
    /// Would a crypto operation of `rub` ₽ exceed the неквал ceiling? (§2.4)
    func cryptoTradeExceedsLimit(rub: Double, investorStatus: InvestorStatus) -> Bool {
        guard investorStatus == .unqualified else { return false }
        return investorUsedRub + rub > CryptoCompliance.yearlyLimitRub
    }

    func passRiskTest() { riskTestPassed = true }

    // MARK: - Portfolio (live valuation)

    /// Crypto positions = Ромео custodial wallets + linked watch-only external wallets (§9.6).
    func cryptoPositions(using price: LivePriceService) -> [CryptoPosition] {
        var rows: [CryptoPosition] = []
        for w in bankWallets where w.balance > 0 {
            let unit = price.price(w.asset)
            rows.append(CryptoPosition(
                id: "bank-\(w.id)", symbol: w.asset, title: CryptoCatalog.name(w.asset),
                subtitle: "Кошелёк · \(CryptoCatalog.chainLabel(w.asset))",
                qty: w.balance, unitPriceRub: unit, valueRub: unit * w.balance,
                change24hPct: price.change24h(w.asset), kind: .bankCrypto, watchOnly: false, routeId: w.asset))
        }
        for wallet in externalWallets {
            for h in wallet.holdings where h.balance > 0 {
                let unit = price.price(h.asset)
                rows.append(CryptoPosition(
                    id: "ext-\(wallet.id)-\(h.asset)", symbol: h.asset, title: CryptoCatalog.name(h.asset),
                    subtitle: "\(wallet.provider.label) · \(wallet.shortAddress)",
                    qty: h.balance, unitPriceRub: unit, valueRub: unit * h.balance,
                    change24hPct: price.change24h(h.asset), kind: .externalCrypto, watchOnly: true, routeId: h.asset))
            }
        }
        return rows.sorted { $0.valueRub > $1.valueRub }
    }

    func cfaPositions() -> [CryptoPosition] {
        cfaHoldings.compactMap { holding in
            guard let c = MockCryptoData.cdfa(holding.cdfaId), holding.units > 0 else { return nil }
            return CryptoPosition(
                id: "cfa-\(holding.id)", symbol: c.ticker, title: c.name, subtitle: c.issuer,
                qty: holding.units, unitPriceRub: c.priceRub, valueRub: holding.units * c.priceRub,
                change24hPct: c.dayChangePct, kind: .cfa, watchOnly: false, routeId: c.id)
        }
        .sorted { $0.valueRub > $1.valueRub }
    }

    func summary(using price: LivePriceService) -> PortfolioSummary {
        let crypto = cryptoPositions(using: price)
        let cfa = cfaPositions()
        let cryptoRub = crypto.reduce(0) { $0 + $1.valueRub }
        let externalRub = crypto.filter(\.watchOnly).reduce(0) { $0 + $1.valueRub }
        let cfaRub = cfa.reduce(0) { $0 + $1.valueRub }
        let total = cryptoRub + cfaRub
        let changeRub = (crypto + cfa).reduce(0) { $0 + $1.valueRub * (($1.change24hPct ?? 0) / 100) }
        let pct = total > 0 ? changeRub / total * 100 : 0
        return PortfolioSummary(totalRub: total, cryptoRub: cryptoRub, cfaRub: cfaRub,
                                externalRub: externalRub, change24hRub: changeRub, change24hPct: pct)
    }

    // MARK: - Mutations · crypto (simulated against live prices)

    func buy(asset: String, qty: Double, rubCost: Double) {
        adjustBank(asset: asset, delta: qty)
        recordCryptoVolume(rubCost)
        appendActivity(.buy, asset: asset, qty: qty, rub: -rubCost,   // ₽ outflow (paid)
                       title: "Покупка \(asset.uppercased())", subtitle: "Маркет · по курсу")
        appendOrder(asset: asset, side: .buy, qty: qty, price: rubCost / max(qty, .leastNonzeroMagnitude))
    }

    func sell(asset: String, qty: Double, rubProceeds: Double) {
        adjustBank(asset: asset, delta: -qty)
        recordCryptoVolume(rubProceeds)
        appendActivity(.sell, asset: asset, qty: qty, rub: rubProceeds,   // ₽ inflow (received)
                       title: "Продажа \(asset.uppercased())", subtitle: "Маркет · по курсу")
        appendOrder(asset: asset, side: .sell, qty: qty, price: rubProceeds / max(qty, .leastNonzeroMagnitude))
    }

    /// Crypto → ₽ (instant). Debits the asset; the ₽ proceeds are notionally credited to the fiat side.
    func convertToRub(asset: String, qty: Double, rubProceeds: Double) {
        adjustBank(asset: asset, delta: -qty)
        recordCryptoVolume(rubProceeds)
        appendActivity(.convert, asset: asset, qty: qty, rub: rubProceeds,
                       title: "\(asset.uppercased()) → ₽", subtitle: "Мгновенно")
    }

    /// ₽ → crypto (instant). Credits the asset.
    func convertFromRub(asset: String, qty: Double, rubCost: Double) {
        adjustBank(asset: asset, delta: qty)
        recordCryptoVolume(rubCost)
        appendActivity(.convert, asset: asset, qty: qty, rub: -rubCost,
                       title: "₽ → \(asset.uppercased())", subtitle: "Мгновенно")
    }

    /// Stablecoin 1:1 swap (USDT ↔ USDC) — equal ₽ value, no investor-limit impact for the swap itself.
    func swapStable(from: String, to: String, qty: Double, rubValue: Double) {
        adjustBank(asset: from, delta: -qty)
        adjustBank(asset: to, delta: qty)
        appendActivity(.convert, asset: to, qty: qty, rub: 0,
                       title: "\(from.uppercased()) → \(to.uppercased())", subtitle: "Стейблкоин 1:1")
    }

    func send(asset: String, qty: Double, rubValue: Double, to recipient: String, network: String) {
        adjustBank(asset: asset, delta: -qty)
        recordCryptoVolume(rubValue)
        appendActivity(.send, asset: asset, qty: qty, rub: -rubValue,
                       title: "Отправка \(asset.uppercased())", subtitle: "\(recipient) · \(network)")
    }

    /// A limit order: placed **open** (not filled), so balances are untouched until execution. Logged
    /// to the activity feed and surfaced in the order list as `.open`.
    func placeLimitOrder(asset: String, side: OrderSide, qty: Double, price: Double) {
        seq += 1
        orders.insert(Order(id: "o_lim_\(seq)", profileId: profileId, asset: asset.uppercased(),
                            side: side, type: .limit, qty: qty, price: price, status: .open,
                            createdAt: ISO8601DateFormatter().string(from: Date())), at: 0)
        appendActivity(side == .buy ? .buy : .sell, asset: asset, qty: qty,
                       rub: side == .buy ? -(qty * price) : (qty * price),
                       title: "Лимит · \(side == .buy ? "покупка" : "продажа") \(asset.uppercased())",
                       subtitle: "Размещён · \(CryptoFormat.rub(price, fraction: 0))")
    }

    /// Cancel an OPEN limit order (§9.6 «История сделок»). Flips its status to `.canceled` so it drops
    /// out of the open-orders list; balances were never touched (the order never filled). No-op for an
    /// order that's already filled/canceled. Simulation — no backend.
    func cancelOrder(id: String) {
        guard let i = orders.firstIndex(where: { $0.id == id }), orders[i].status == .open else { return }
        let o = orders[i]
        orders[i] = Order(id: o.id, profileId: o.profileId, asset: o.asset, side: o.side,
                          type: o.type, qty: o.qty, price: o.price, status: .canceled, createdAt: o.createdAt)
    }

    // MARK: - Mutations · ЦФА (legal path — NOT counted against the crypto limit, §2.4)

    func buyCDFA(_ cdfa: CDFA, units: Double) {
        let rub = units * cdfa.priceRub
        if let i = cfaHoldings.firstIndex(where: { $0.cdfaId == cdfa.id }) {
            cfaHoldings[i].units += units
        } else {
            seq += 1
            cfaHoldings.append(CDFAHolding(id: "h_\(cdfa.id)_\(seq)", cdfaId: cdfa.id, units: units))
        }
        appendActivity(.cfaBuy, asset: cdfa.ticker, qty: units, rub: -rub,
                       title: "Покупка \(cdfa.ticker)", subtitle: cdfa.issuer)
    }

    // MARK: - Mutations · external wallets (watch-only)

    @discardableResult
    func linkExternalWallet(provider: ExternalWalletProvider, address: String, label: String?) -> ExternalWallet {
        seq += 1
        let wallet = ExternalWallet(
            id: "ext_\(provider.rawValue)_\(seq)",
            provider: provider,
            address: address,
            label: label?.isEmpty == false ? label! : provider.label,
            holdings: MockCryptoData.mockHoldings(provider: provider, address: address)
        )
        externalWallets.append(wallet)
        return wallet
    }

    /// Unlink (forget) a watch-only external wallet (§9.6). Removing it from `externalWallets` drops its
    /// holdings from the unified portfolio — `cryptoPositions`/`summary` recompute, so the dashboard total
    /// and the «Внешние кошельки» list both update live. The wallet was watch-only, so nothing else moves.
    func unlinkExternalWallet(id: String) {
        externalWallets.removeAll { $0.id == id }
    }

    // MARK: - Private

    private func recordCryptoVolume(_ rub: Double) { investorUsedRub += abs(rub) }

    private func adjustBank(asset: String, delta: Double) {
        let key = asset.uppercased()
        if let i = bankWallets.firstIndex(where: { $0.asset.uppercased() == key }) {
            let w = bankWallets[i]
            bankWallets[i] = CryptoWallet(id: w.id, profileId: w.profileId, asset: w.asset,
                                          chain: w.chain, address: w.address, balance: max(0, w.balance + delta))
        } else if delta > 0 {
            seq += 1
            bankWallets.append(CryptoWallet(id: "w_\(key.lowercased())_\(seq)", profileId: profileId,
                                            asset: key, chain: CryptoCatalog.chainLabel(key),
                                            address: "ro_\(key.lowercased())_demo", balance: delta))
        }
    }

    private func appendActivity(_ kind: CryptoActivityKind, asset: String, qty: Double, rub: Double,
                                title: String, subtitle: String) {
        seq += 1
        activity.insert(CryptoActivity(id: "act_\(seq)", kind: kind, title: title, subtitle: subtitle,
                                       asset: asset.uppercased(), qty: qty, rubAmount: rub, at: Date()), at: 0)
    }

    private func appendOrder(asset: String, side: OrderSide, qty: Double, price: Double) {
        seq += 1
        orders.insert(Order(id: "o_new_\(seq)", profileId: profileId, asset: asset.uppercased(),
                            side: side, type: .market, qty: qty, price: price, status: .filled,
                            createdAt: ISO8601DateFormatter().string(from: Date())), at: 0)
    }

    private static func seedActivity(orders: [Order], profileId: String) -> [CryptoActivity] {
        let iso = ISO8601DateFormatter()
        let mapped: [CryptoActivity] = orders.map { order in
            let rub = (order.price ?? 0) * order.qty
            return CryptoActivity(
                id: "seed_\(order.id)",
                kind: order.side == .buy ? .buy : .sell,
                title: "\(order.side == .buy ? "Покупка" : "Продажа") \(order.asset)",
                subtitle: "\(order.type == .market ? "Маркет" : "Лимит") · \(order.status.rawValue)",
                asset: order.asset, qty: order.qty,
                rubAmount: order.side == .buy ? -rub : rub,
                at: iso.date(from: order.createdAt) ?? Date())
        }
        return mapped.sorted { $0.at > $1.at }
    }
}
