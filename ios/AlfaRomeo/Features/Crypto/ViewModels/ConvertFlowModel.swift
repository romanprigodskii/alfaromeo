import Foundation
import Observation

/// «Конвертация крипто↔₽ (мгновенно) и крипто↔стейблкоин 1:1» (§9.6). Amount → preview (курс по
/// live-цене, спред зависит от тира) → биометрия → исполнение (симуляция по live-цене). Carries a
/// time-boxed ``CryptoQuote`` so the «re-quote с TTL при волатильности» edge case is real (§10.8).
@MainActor
@Observable
final class ConvertFlowModel {
    enum Step: Hashable { case amount, confirm, status }
    enum Direction: String, CaseIterable, Identifiable {
        case sell   // крипто → ₽
        case buy    // ₽ → крипто
        case swap   // стейблкоин ↔ стейблкоин 1:1
        var id: String { rawValue }
        var label: String {
            switch self {
            case .sell: return "Крипто → ₽"
            case .buy:  return "₽ → Крипто"
            case .swap: return "Стейбл 1:1"
            }
        }
    }

    var asset: String
    var counterStable: String   // swap target (the other stablecoin)
    var direction: Direction
    var amountText = ""
    var inputInAsset = true

    var spreadTier: Entitlements.SpreadTier = .standard
    var investorStatus: InvestorStatus = .unqualified
    var rubAvailable: Double = 0

    var step: Step = .amount
    private(set) var quote: CryptoQuote?
    var authorizing = false
    var outcome: CryptoOutcome?

    init(asset: String?) {
        let symbol = (asset ?? "BTC").uppercased()
        self.asset = symbol
        self.direction = CryptoCatalog.isStable(symbol) ? .swap : .sell
        self.counterStable = symbol == "USDT" ? "USDC" : "USDT"
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
    }

    // MARK: Direction / asset selection

    var canSwap: Bool { CryptoCatalog.isStable(asset) }

    func setDirection(_ d: Direction) {
        guard d != direction else { return }
        // Swap only applies to stablecoins; for others fall back to sell.
        direction = (d == .swap && !canSwap) ? .sell : d
        rebuildQuote()
    }

    func setAsset(_ symbol: String) {
        asset = symbol.uppercased()
        counterStable = asset == "USDT" ? "USDC" : "USDT"
        if direction == .swap && !canSwap { direction = .sell }
        rebuildQuote()
    }

    // MARK: Pricing

    var midPrice: Double { LivePriceService.shared.price(asset) }
    var spreadPct: Double { direction == .swap ? 0 : CryptoSpread.pct(for: spreadTier) }
    var effectiveRate: Double { quote?.rate ?? midPrice }

    private var raw: Double { CryptoFormat.parse(amountText) }

    /// Amount in the crypto asset's units.
    var assetAmount: Double {
        switch direction {
        case .swap: return raw
        case .sell, .buy: return inputInAsset ? raw : (effectiveRate > 0 ? raw / effectiveRate : 0)
        }
    }

    /// The ₽ value of the operation.
    var rubAmount: Double {
        switch direction {
        case .swap: return assetAmount * midPrice
        case .sell, .buy: return assetAmount * effectiveRate
        }
    }

    var payText: String {
        switch direction {
        case .sell: return CryptoFormat.qty(assetAmount, symbol: asset)
        case .buy:  return CryptoFormat.rub(rubAmount, fraction: 0)
        case .swap: return CryptoFormat.qty(assetAmount, symbol: asset)
        }
    }
    var getText: String {
        switch direction {
        case .sell: return CryptoFormat.rub(rubAmount, fraction: 0)
        case .buy:  return CryptoFormat.qty(assetAmount, symbol: asset)
        case .swap: return CryptoFormat.qty(assetAmount, symbol: counterStable)
        }
    }
    var getSymbol: String {
        switch direction {
        case .sell: return "₽"
        case .buy:  return asset
        case .swap: return counterStable
        }
    }

    var entrySymbol: String {
        switch direction {
        case .buy:  return inputInAsset ? asset : "₽"
        case .sell, .swap: return inputInAsset ? asset : "₽"
        }
    }

    var balance: Double { CryptoStore.shared.bankBalance(asset: asset) }

    // MARK: Gate

    enum Gate: Equatable { case ok, empty, investorLimit(remaining: Double) }
    var gate: Gate {
        guard raw > 0 else { return .empty }
        if direction != .swap,
           CryptoStore.shared.cryptoTradeExceedsLimit(rub: rubAmount, investorStatus: investorStatus) {
            return .investorLimit(remaining: CryptoStore.shared.investorRemainingRub)
        }
        return .ok
    }
    var canProceed: Bool { gate == .ok }

    var insufficientFunds: Bool {
        switch direction {
        case .buy:  return rubAmount > rubAvailable
        case .sell, .swap: return assetAmount > balance
        }
    }

    // MARK: Quote / TTL

    func rebuildQuote() {
        let side: CryptoSide = direction == .buy ? .buy : .sell
        quote = CryptoQuote(asset: asset, side: side, midPriceRub: midPrice, spreadPct: spreadPct, createdAt: Date())
    }

    func quoteExpired(at now: Date) -> Bool { quote?.isExpired(at: now) ?? false }
    func quoteRemaining(at now: Date) -> TimeInterval { quote?.remaining(at: now) ?? 0 }

    // MARK: Steps

    func goToConfirm() {
        guard canProceed else { return }
        rebuildQuote()
        step = .confirm
    }
    func backToAmount() { step = .amount }

    func authorize() async {
        // Re-quote on a stale rate instead of executing (volatility edge, §10.8).
        if quoteExpired(at: Date()) { rebuildQuote(); return }
        authorizing = true
        let ok = await BiometricAuthenticator.authenticate(reason: "Подтвердить конвертацию \(payText)")
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
        step = .amount
    }

    private func computeSettlement() -> CryptoOutcome {
        if quoteExpired(at: Date()) { return .declined(.quoteExpired) }
        if insufficientFunds { return .declined(.insufficientFunds) }
        return .success
    }

    private func commit() {
        switch direction {
        case .sell: CryptoStore.shared.convertToRub(asset: asset, qty: assetAmount, rubProceeds: rubAmount)
        case .buy:  CryptoStore.shared.convertFromRub(asset: asset, qty: assetAmount, rubCost: rubAmount)
        case .swap: CryptoStore.shared.swapStable(from: asset, to: counterStable, qty: assetAmount, rubValue: rubAmount)
        }
    }
}
