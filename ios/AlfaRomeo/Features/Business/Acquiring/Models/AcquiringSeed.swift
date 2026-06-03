import Foundation

/// Self-contained demo seed for the acquiring module.
///
/// The ``APIClient`` protocol doesn't expose acquiring points / revenue (and `Networking/` is out of
/// scope for this module), so the hub seeds its own fixtures — mirroring the «every mutation is a
/// simulation» rule the rest of Ромео-Бизнес follows. Reuses the Core ``AcquiringPoint`` contract for
/// the configured acceptance points.
enum AcquiringSeed {
    /// Configured acceptance points shown on the hub.
    static func points(businessId: String) -> [AcquiringPoint] {
        [
            AcquiringPoint(id: "ap_qr",   businessId: businessId, type: .qr,       label: "Касса №1 · QR"),
            AcquiringPoint(id: "ap_term", businessId: businessId, type: .terminal, label: "Терминал у входа"),
            AcquiringPoint(id: "ap_link", businessId: businessId, type: .link,     label: "Платёжная ссылка"),
            AcquiringPoint(id: "ap_crp",  businessId: businessId, type: .crypto,   label: "USDT-приём · авто-₽"),
        ]
    }

    /// Seed revenue history (₽ уже зачислены). Crypto rows carry the stable amount that was
    /// auto-converted. Dates are recent offsets from now so the report reads as «за сегодня».
    static func revenue() -> [RevenueEntry] {
        let now = Date()
        func ago(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }
        return [
            RevenueEntry(id: "rev1", method: .card,         grossRub: 12_400, counterparty: "Касса №1",         createdAt: ago(1.5), cryptoAsset: nil,    cryptoAmount: nil),
            RevenueEntry(id: "rev2", method: .sbp,          grossRub: 3_250,  counterparty: "СБП · покупка",     createdAt: ago(3),   cryptoAsset: nil,    cryptoAmount: nil),
            RevenueEntry(id: "rev3", method: .crypto,       grossRub: 91_500, counterparty: "USDT-приём · авто-₽", createdAt: ago(6), cryptoAsset: "USDT", cryptoAmount: 1_000),
            RevenueEntry(id: "rev4", method: .card,         grossRub: 7_800,  counterparty: "Платёжная ссылка",  createdAt: ago(20),  cryptoAsset: nil,    cryptoAmount: nil),
            RevenueEntry(id: "rev5", method: .digitalRuble, grossRub: 15_000, counterparty: "Цифровой ₽ · QR",   createdAt: ago(28),  cryptoAsset: nil,    cryptoAmount: nil),
            RevenueEntry(id: "rev6", method: .sbp,          grossRub: 2_100,  counterparty: "СБП · покупка",     createdAt: ago(46),  cryptoAsset: nil,    cryptoAmount: nil),
            RevenueEntry(id: "rev7", method: .crypto,       grossRub: 45_800, counterparty: "USDC-приём · авто-₽", createdAt: ago(52), cryptoAsset: "USDC", cryptoAmount: 500),
        ]
    }
}
