import Foundation

/// Точка приёма оплаты на хабе эквайринга (§8.2): онлайн / офлайн / крипто.
///
/// Pure presentation metadata for the three acceptance channels shown on ``AcquiringHubView``. The
/// crypto channel is the differentiator — приём стейблов с авто-конвертацией в ₽ по live-курсу (§2.4).
enum AcquiringChannel: String, CaseIterable, Identifiable, Hashable, Sendable {
    case online    // платёжные линки / интернет-эквайринг
    case offline   // QR / NFC / терминал
    case crypto    // приём стейблов с авто-конвертацией в ₽

    var id: String { rawValue }

    var title: String {
        switch self {
        case .online:  return "Онлайн"
        case .offline: return "Офлайн"
        case .crypto:  return "Крипто-эквайринг"
        }
    }

    var subtitle: String {
        switch self {
        case .online:  return "Платёжные ссылки и интернет-эквайринг"
        case .offline: return "QR, NFC и терминал на кассе"
        case .crypto:  return "Стейблкоины с конвертацией в ₽ по live-курсу"
        }
    }

    var systemImage: String {
        switch self {
        case .online:  return "link"
        case .offline: return "qrcode.viewfinder"
        case .crypto:  return "bitcoinsign"
        }
    }

    /// Capability chips shown on the channel card.
    var methods: [String] {
        switch self {
        case .online:  return ["Платёжная ссылка", "интернет-эквайринг", "рекуррентные"]
        case .offline: return ["QR", "NFC", "Терминал"]
        case .crypto:  return ["USDT", "USDC", "конвертация в ₽"]
        }
    }
}
