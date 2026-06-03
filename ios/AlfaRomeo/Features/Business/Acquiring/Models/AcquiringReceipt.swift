import Foundation

/// Чек по принятой оплате (§8.3) — симуляция зачисления на расчётный счёт, как остальные мутации.
///
/// For crypto, `grossAmount` is the stablecoin amount the client paid and `liveRate`/`cryptoAmount`
/// describe the auto-conversion; `creditedRub` is what landed in ₽ after the conversion + fee.
struct AcquiringReceipt: Identifiable, Hashable, Sendable {
    let id: String
    let receiptNo: String
    let method: PaymentMethod

    /// Сколько заплатил клиент, в валюте оплаты (₽ или стейбл).
    let grossAmount: Double
    /// Символ валюты оплаты: "₽" или "USDT"/"USDC".
    let payCurrency: String

    /// Зачислено на расчётный счёт в ₽ (после конвертации и комиссии).
    let creditedRub: Double
    let feeRub: Double

    /// Только для крипто-приёма: live-курс ₽ за 1 единицу стейбла + объём.
    let liveRate: Double?
    let cryptoAmount: Double?
    let cryptoAsset: String?

    let createdAt: Date

    var wasCrypto: Bool { method.isCrypto }
}
