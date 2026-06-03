import Foundation
import Observation

/// «Трейдинг/ордер: маркет/лимит» (§9.6). Market orders fill instantly at the live rate + tier spread;
/// limit orders are placed open at the user's price. Preview → биометрия → исполнение (симуляция).
/// Market quotes carry a TTL so a stale rate forces a re-quote during volatility (§10.8).
@MainActor
@Observable
final class TradeOrderModel {
    enum Step: Hashable { case form, confirm, status }

    let symbol: String
    var side: CryptoSide
    var orderType: OrderType = .market
    var amountText = ""           // qty in asset units
    var limitPriceText = ""       // ₽ per unit (limit orders)
    var totalText = ""            // ₽ объём — linked to qty ↔ total via setQty / setTotal

    // Advanced **spot** order options (Bybit-ticket density). Visual for the demo: the store settles
    // market/limit only, so these are surfaced in the confirm summary as order parameters, never
    // leverage. Post-Only is meaningful for limit orders only (§2.4 — спот, без плеча/деривативов).
    var tpEnabled = false
    var tpPriceText = ""
    var slEnabled = false
    var slPriceText = ""
    var postOnly = false
    var goodTillCanceled = true

    var spreadTier: Entitlements.SpreadTier = .standard
    var investorStatus: InvestorStatus = .unqualified
    var rubAvailable: Double = 0

    var step: Step = .form
    private(set) var quote: CryptoQuote?
    var authorizing = false
    var outcome: CryptoOutcome?
    private(set) var placedLimit = false

    init(symbol: String, side: CryptoSide, prefilledPrice: Double? = nil) {
        self.symbol = symbol.uppercased()
        self.side = side
        // Tapping an order-book level prefills a limit at that price (§9.6 биржевой UX).
        if let p = prefilledPrice, p > 0 {
            orderType = .limit
            limitPriceText = CryptoFormat.plain(p)
        }
    }

    func load(api: any APIClient, session: AppSession) async {
        investorStatus = session.currentUser?.investorStatus ?? .unqualified
        let profileId = session.activeProfile?.id ?? ""
        let fallback = (try? await api.subscription(profileId: profileId))?.tier ?? .base
        let tier = session.currentTier(for: profileId, fallback: fallback)
        spreadTier = Entitlements.make(for: tier).cryptoSpread
        if let accounts = try? await api.accounts(profileId: profileId) {
            rubAvailable = accounts.filter { $0.currency == "RUB" }.reduce(0) { $0 + $1.balance }
        }
        if limitPriceText.isEmpty { limitPriceText = CryptoFormat.plain(midPrice) }
        syncTotalFromQty()
    }

    // MARK: Pricing

    var midPrice: Double { LivePriceService.shared.price(symbol) }
    var spreadPct: Double { CryptoSpread.pct(for: spreadTier) }
    private var qty: Double { CryptoFormat.parse(amountText) }
    private var limitPrice: Double { CryptoFormat.parse(limitPriceText) }

    // MARK: Цена ↔ Количество ↔ Объём (Bybit ticket linkage)

    /// Set quantity (asset units); derive the ₽ объём.
    func setQty(_ s: String) {
        amountText = s
        let q = CryptoFormat.parse(s)
        totalText = (q > 0 && execRate > 0) ? CryptoFormat.plain(q * execRate) : ""
    }
    /// Set the ₽ объём; back-derive the quantity at the current rate.
    func setTotal(_ s: String) {
        totalText = s
        let t = CryptoFormat.parse(s)
        amountText = (t > 0 && execRate > 0) ? CryptoFormat.plain(t / execRate) : ""
    }
    /// Re-derive the объём after the rate changes (side / type / limit-price edits).
    func syncTotalFromQty() {
        let q = CryptoFormat.parse(amountText)
        totalText = (q > 0 && execRate > 0) ? CryptoFormat.plain(q * execRate) : ""
    }

    /// Max tradable quantity for the 25/50/75/100 % slider: % of ₽ available (buy) or asset balance (sell).
    var maxQty: Double {
        switch side {
        // Shave a hair so the 8-dp qty string round-trip (plain → parse) stays at-or-below available
        // and a 100 % slider never trips insufficientFunds on the ₽ side.
        case .buy:  return execRate > 0 ? (rubAvailable / execRate) * (1 - 1e-6) : 0
        case .sell: return balance
        }
    }
    var percentFraction: Double {
        let m = maxQty
        guard m > 0 else { return 0 }
        return min(1, max(0, qty / m))
    }
    func applyPercent(_ p: Double) {
        setQty(CryptoFormat.plain(maxQty * min(1, max(0, p))))
    }

    /// Execution rate: market folds in spread (quote), limit uses the user's price.
    var execRate: Double {
        switch orderType {
        case .market: return quote?.rate ?? (side == .buy ? midPrice * (1 + spreadPct) : midPrice * (1 - spreadPct))
        case .limit:  return limitPrice
        }
    }

    var assetAmount: Double { qty }
    var rubAmount: Double { assetAmount * execRate }
    var balance: Double { CryptoStore.shared.bankBalance(asset: symbol) }

    // MARK: Gate

    enum Gate: Equatable { case ok, empty, investorLimit(remaining: Double) }
    var gate: Gate {
        guard qty > 0, execRate > 0 else { return .empty }
        if CryptoStore.shared.cryptoTradeExceedsLimit(rub: rubAmount, investorStatus: investorStatus) {
            return .investorLimit(remaining: CryptoStore.shared.investorRemainingRub)
        }
        return .ok
    }
    var canProceed: Bool { gate == .ok }

    var insufficientFunds: Bool {
        switch side {
        case .buy:  return rubAmount > rubAvailable
        case .sell: return assetAmount > balance
        }
    }

    // MARK: Quote / TTL (market only)

    func rebuildQuote() {
        quote = CryptoQuote(asset: symbol, side: side, midPriceRub: midPrice, spreadPct: spreadPct, createdAt: Date())
    }
    var usesQuote: Bool { orderType == .market }
    func quoteExpired(at now: Date) -> Bool { usesQuote ? (quote?.isExpired(at: now) ?? false) : false }
    func quoteRemaining(at now: Date) -> TimeInterval { quote?.remaining(at: now) ?? 0 }

    // MARK: Steps

    func goToConfirm() {
        guard canProceed else { return }
        if orderType == .market { rebuildQuote() }
        step = .confirm
    }
    func backToForm() { step = .form }

    var confirmVerb: String {
        switch (orderType, side) {
        case (.market, .buy):  return "Купить · Face ID"
        case (.market, .sell): return "Продать · Face ID"
        case (.limit, _):      return "Разместить ордер · Face ID"
        }
    }

    func authorize() async {
        if orderType == .market, quoteExpired(at: Date()) { rebuildQuote(); return }
        authorizing = true
        let ok = await BiometricAuthenticator.authenticate(reason: "\(side == .buy ? "Купить" : "Продать") \(CryptoFormat.qty(assetAmount, symbol: symbol))")
        authorizing = false
        guard ok else { outcome = .declined(.canceled); step = .status; return }
        outcome = .processing
        step = .status
        try? await Task.sleep(for: .seconds(1.4))
        let result = computeSettlement()
        if case .success = result { commit() }
        outcome = result
    }

    func retry() {
        outcome = nil
        placedLimit = false
        step = .form
    }

    private func computeSettlement() -> CryptoOutcome {
        if orderType == .market, quoteExpired(at: Date()) { return .declined(.quoteExpired) }
        // A limit order is placed (no immediate settlement) — only a market order checks funds now.
        if orderType == .market, insufficientFunds { return .declined(.insufficientFunds) }
        return .success
    }

    private func commit() {
        switch orderType {
        case .market:
            if side == .buy { CryptoStore.shared.buy(asset: symbol, qty: assetAmount, rubCost: rubAmount) }
            else { CryptoStore.shared.sell(asset: symbol, qty: assetAmount, rubProceeds: rubAmount) }
        case .limit:
            let orderSide: OrderSide = side == .buy ? .buy : .sell
            CryptoStore.shared.placeLimitOrder(asset: symbol, side: orderSide, qty: assetAmount, price: limitPrice)
            placedLimit = true
        }
    }
}
