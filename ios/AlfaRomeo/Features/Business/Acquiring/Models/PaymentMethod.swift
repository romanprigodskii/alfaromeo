import Foundation

/// How a client pays a business at the till / link (§8.3): карта, СБП, цифровой рубль или крипта.
///
/// Each method carries a demo acquiring fee taken on settlement. The crypto fee bundles the
/// auto-conversion spread (стейбл → ₽ по live-курсу, §2.4) — there is no separate FX line.
enum PaymentMethod: String, CaseIterable, Identifiable, Hashable, Sendable {
    case card
    case sbp
    case digitalRuble
    case crypto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .card:         return "Карта"
        case .sbp:          return "СБП"
        case .digitalRuble: return "Цифровой ₽"
        case .crypto:       return "Крипта (стейбл)"
        }
    }

    var subtitle: String {
        switch self {
        case .card:         return "Visa, Mastercard, МИР"
        case .sbp:          return "QR или номер телефона"
        case .digitalRuble: return "Платформа ЦБ, мгновенно"
        case .crypto:       return "USDT и USDC с конвертацией в ₽"
        }
    }

    var systemImage: String {
        switch self {
        case .card:         return "creditcard.fill"
        case .sbp:          return "qrcode"
        case .digitalRuble: return "rublesign.circle.fill"
        case .crypto:       return "bitcoinsign.circle.fill"
        }
    }

    var isCrypto: Bool { self == .crypto }

    /// Acquiring fee taken on settlement (demo). Crypto bundles the conversion spread; цифровой рубль
    /// is fee-free (нарратив §2.4 — нативный инструмент ЦБ).
    var feeRate: Double {
        switch self {
        case .card:         return 0.015   // 1,5 %
        case .sbp:          return 0.007   // 0,7 %
        case .digitalRuble: return 0.0
        case .crypto:       return 0.009   // 0,9 % (конвертация под капотом)
        }
    }

    /// Short fee label for the receipt / confirm rows.
    var feeLabel: String {
        switch self {
        case .card:         return "1,5 %"
        case .sbp:          return "0,7 %"
        case .digitalRuble: return "Без комиссии"
        case .crypto:       return "0,9 % (конвертация)"
        }
    }
}
