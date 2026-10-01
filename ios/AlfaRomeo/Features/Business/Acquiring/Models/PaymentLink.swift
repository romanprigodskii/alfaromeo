import Foundation

/// Сгенерированный платёжный линк или QR (§8.3) — мок-генерация для приёма оплаты, как остальные
/// мутации бизнес-режима.
struct PaymentLink: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Identifiable, Hashable, Sendable {
        case link, qr

        var id: String { rawValue }

        var title: String { self == .link ? "Платёжная ссылка" : "QR-код" }
        var systemImage: String { self == .link ? "link" : "qrcode" }
        var actionTitle: String { self == .link ? "Создать ссылку" : "Создать QR" }
        var hint: String {
            self == .link
                ? "Отправьте ссылку клиенту в мессенджер. Оплата картой, СБП, цифровым рублём или криптой."
                : "Покажите QR на кассе: клиент сканирует его камерой и платит любым способом."
        }
    }

    let id: String
    let kind: Kind
    let amount: Double
    let purpose: String
    let url: String
    let createdAt: Date
}
