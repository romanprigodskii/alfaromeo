import Foundation
import Observation

/// Shared, in-memory acquiring state for Ромео-Бизнес (§8.2 — мок-эквайринг).
///
/// Mirrors the ``MobileStore`` / ``CardsStore`` pattern: a `@MainActor @Observable` singleton held via
/// `@State` in each screen, so a payment link created in one flow, an accepted payment, and the
/// revenue feed all reflect live across the hub and its sub-screens — без общего предка во view-дереве
/// (routes are independent views on the section ``Router``). It hydrates once per business profile from
/// the read-only ``APIClient`` (юрлицо + счета); acquiring points / revenue are seeded locally
/// (``AcquiringSeed``) since the protocol doesn't expose them. Every mutation below is a simulation.
///
/// Крипто-эквайринг считает зачисление по **реальному live-курсу** из ``LivePriceService`` (тот же
/// источник, что и Crypto Hub) — стейбл → ₽ под капотом (§2.4).
@MainActor
@Observable
final class AcquiringStore {
    static let shared = AcquiringStore()

    private(set) var business: Business?
    /// Расчётный ₽-счёт, на который зачисляется выручка (растёт при приёме оплаты).
    private(set) var settlementBalanceRub: Double = 0
    /// Крипто-трежери (стейблы) — операционная валюта (§8.2).
    private(set) var cryptoTreasuryUsdt: Double = 0
    private(set) var points: [AcquiringPoint] = []
    private(set) var links: [PaymentLink] = []
    private(set) var revenue: [RevenueEntry] = []

    private(set) var didLoad = false
    private(set) var loadFailed = false

    private var loadedProfileId: String?
    private var seq = 0

    private init() {}

    var businessName: String { business?.name ?? "Бизнес" }

    // MARK: - Load (once per business profile)

    func load(api: any APIClient, profileId: String, force: Bool = false) async {
        guard !profileId.isEmpty, force || loadedProfileId != profileId else { return }
        do {
            let biz = try await api.business(profileId: profileId)
            let accounts = (try? await api.accounts(profileId: profileId)) ?? []
            business = biz
            settlementBalanceRub = accounts.first { $0.type == .current && $0.currency == "RUB" }?.balance ?? 0
            cryptoTreasuryUsdt = accounts.first { $0.type == .crypto }?.balance ?? 0
            let bid = biz?.profileId ?? profileId
            points = AcquiringSeed.points(businessId: bid)
            revenue = AcquiringSeed.revenue()
            loadFailed = false
            didLoad = true
            loadedProfileId = profileId          // commit only on success → a failed load can retry
        } catch {
            loadFailed = true
            didLoad = true
        }
    }

    // MARK: - Live crypto conversion (§2.4)

    /// Live ₽ rate for 1 unit of a stablecoin, from the real price service (REST + ``PriceSocket``).
    func rubRate(asset: String) -> Double { LivePriceService.shared.price(asset) }
    var pricesAreLive: Bool { LivePriceService.shared.isLive }

    /// ₽ value of a stablecoin amount at the live rate.
    func convertedRub(stableAmount: Double, asset: String) -> Double {
        stableAmount * rubRate(asset: asset)
    }

    /// Stablecoin amount equivalent to a ₽ price at the live rate.
    func stableAmount(forRub rub: Double, asset: String) -> Double {
        let rate = rubRate(asset: asset)
        return rate > 0 ? rub / rate : 0
    }

    // MARK: - Derivations

    func summary() -> RevenueSummary {
        let total = revenue.reduce(0) { $0 + $1.grossRub }
        let crypto = revenue.filter(\.wasCrypto).reduce(0) { $0 + $1.grossRub }
        var slices: [RevenueSummary.MethodSlice] = []
        for method in PaymentMethod.allCases {
            let amount = revenue.filter { $0.method == method }.reduce(0) { $0 + $1.grossRub }
            if amount > 0 { slices.append(.init(method: method, amount: amount)) }
        }
        return RevenueSummary(total: total, count: revenue.count, cryptoConvertedRub: crypto, byMethod: slices)
    }

    func filteredRevenue(_ filter: RevenueFilter) -> [RevenueEntry] {
        revenue.filter(filter.matches).sorted { $0.createdAt > $1.createdAt }
    }

    var recentRevenue: [RevenueEntry] {
        Array(revenue.sorted { $0.createdAt > $1.createdAt }.prefix(3))
    }

    // MARK: - Mutations · payment link / QR (§8.3)

    @discardableResult
    func createLink(amount: Double, purpose: String, kind: PaymentLink.Kind) -> PaymentLink {
        seq += 1
        let token = String(format: "%06x", (seq &* 2_654_435_761) & 0xFFFFFF)
        let cleaned = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = PaymentLink(
            id: "lnk_\(seq)",
            kind: kind,
            amount: amount,
            purpose: cleaned.isEmpty ? "Оплата" : cleaned,
            url: "https://pay.alfa-romeo.uk/i/\(token)",
            createdAt: Date()
        )
        links.insert(link, at: 0)
        return link
    }

    // MARK: - Mutations · accept payment (§8.3)

    /// Settle an accepted payment: credit ₽ to the settlement account, append revenue, return the чек.
    /// For crypto, the stablecoin is auto-converted at the live rate before crediting (§2.4).
    @discardableResult
    func recordSettlement(method: PaymentMethod, priceRub: Double, cryptoAsset: String?) -> AcquiringReceipt {
        seq += 1
        let receiptNo = String(format: "ОР-%05d", 10_000 + seq)
        let createdAt = Date()

        if method.isCrypto, let asset = cryptoAsset {
            let rate = rubRate(asset: asset)
            let stable = rate > 0 ? priceRub / rate : 0
            let grossRubAtRate = stable * rate                 // ≈ priceRub, по live-курсу
            let fee = grossRubAtRate * method.feeRate
            let credited = grossRubAtRate - fee
            settlementBalanceRub += credited
            revenue.insert(
                RevenueEntry(id: "rev_\(seq)", method: method, grossRub: credited,
                             counterparty: "\(asset)-приём · авто-₽", createdAt: createdAt,
                             cryptoAsset: asset, cryptoAmount: stable),
                at: 0
            )
            return AcquiringReceipt(
                id: "rcp_\(seq)", receiptNo: receiptNo, method: method,
                grossAmount: stable, payCurrency: asset, creditedRub: credited, feeRub: fee,
                liveRate: rate, cryptoAmount: stable, cryptoAsset: asset, createdAt: createdAt
            )
        } else {
            let fee = priceRub * method.feeRate
            let credited = priceRub - fee
            settlementBalanceRub += credited
            revenue.insert(
                RevenueEntry(id: "rev_\(seq)", method: method, grossRub: credited,
                             counterparty: counterparty(for: method), createdAt: createdAt,
                             cryptoAsset: nil, cryptoAmount: nil),
                at: 0
            )
            return AcquiringReceipt(
                id: "rcp_\(seq)", receiptNo: receiptNo, method: method,
                grossAmount: priceRub, payCurrency: "₽", creditedRub: credited, feeRub: fee,
                liveRate: nil, cryptoAmount: nil, cryptoAsset: nil, createdAt: createdAt
            )
        }
    }

    private func counterparty(for method: PaymentMethod) -> String {
        switch method {
        case .card:         return "Оплата картой"
        case .sbp:          return "СБП · оплата"
        case .digitalRuble: return "Цифровой ₽"
        case .crypto:       return "Крипто-приём"
        }
    }
}
