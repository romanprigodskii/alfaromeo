import Foundation
import Observation

/// Сценарий приёма оплаты (§8.3, демо): задать сумму → выбрать способ (карта/СБП/цифр.₽/крипта) →
/// если крипта — авто-конвертация в ₽ по **live-курсу** → биометрия → зачисление + чек.
///
/// Mirrors the crypto flow models: amount/preview → ``BiometricAuthenticator`` → анимированный статус.
/// The conversion math reads the same ``LivePriceService`` the Crypto Hub uses, so крипто-приём
/// показывает реальный курс (§2.4). Settlement itself is a simulation through ``AcquiringStore``.
@MainActor
@Observable
final class AcceptPaymentModel {
    enum Step: Hashable { case input, status }

    var step: Step = .input
    /// Цена в ₽, которую выставляет бизнес (клиент платит её любым способом).
    var priceText: String = ""
    var method: PaymentMethod = .card
    /// Для крипто-приёма: какой стейбл принимаем.
    var cryptoAsset: String = "USDT"
    var authorizing = false
    var outcome: AcquiringOutcome?

    let stableAssets = ["USDT", "USDC"]

    var priceRub: Double { CryptoFormat.parse(priceText) }
    var canAccept: Bool { priceRub > 0 }

    // MARK: - Live conversion (only meaningful for crypto)

    /// Live ₽ rate per 1 unit of the selected stablecoin.
    var liveRate: Double { LivePriceService.shared.price(cryptoAsset) }
    var pricesAreLive: Bool { LivePriceService.shared.isLive }
    /// Сколько стейбла платит клиент, чтобы покрыть ₽-цену по live-курсу.
    var stableAmount: Double { liveRate > 0 ? priceRub / liveRate : 0 }

    // MARK: - Settlement preview

    var feeRub: Double { priceRub * method.feeRate }
    /// ₽, которые зачислятся на расчётный счёт (после комиссии/конвертации).
    var creditedRub: Double { priceRub - feeRub }

    // MARK: - Accept

    func authorizeAndSettle(store: AcquiringStore) async {
        guard canAccept, !authorizing else { return }
        authorizing = true
        let reason = method.isCrypto
            ? "Принять \(CryptoFormat.qty(stableAmount, symbol: cryptoAsset)) → \(CryptoFormat.rub(creditedRub))"
            : "Принять оплату \(CryptoFormat.rub(priceRub))"
        let ok = await BiometricAuthenticator.authenticate(reason: reason)
        authorizing = false
        guard ok else { outcome = .declined(.canceled); step = .status; return }

        outcome = .processing
        step = .status
        try? await Task.sleep(for: .seconds(1.4))
        let receipt = store.recordSettlement(
            method: method,
            priceRub: priceRub,
            cryptoAsset: method.isCrypto ? cryptoAsset : nil
        )
        outcome = .settled(receipt)
    }

    func reset() {
        outcome = nil
        step = .input
    }
}
