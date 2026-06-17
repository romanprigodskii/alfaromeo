import Foundation

/// Why a crypto operation was declined on the animated status step (§10.8). The Payments
/// ``DeclineReason`` covers only insufficient funds / cancel; crypto adds the network-congestion and
/// stale-quote edge cases, so the Crypto hub uses its own outcome type (and ``CryptoStatusView``).
enum CryptoDeclineReason: Hashable, Sendable {
    case insufficientFunds
    case canceled
    case networkBusy
    case quoteExpired
    case failed(String)   // a backend error surfaced verbatim (friendly text), e.g. recipient not found

    var title: String {
        switch self {
        case .insufficientFunds: return "Операция отклонена"
        case .canceled:          return "Операция отменена"
        case .networkBusy:       return "Сеть перегружена"
        case .quoteExpired:      return "Курс устарел"
        case .failed:            return "Не удалось отправить"
        }
    }

    var message: String {
        switch self {
        case .insufficientFunds: return "Недостаточно средств на кошельке. Уменьшите сумму и попробуйте снова."
        case .canceled:          return "Подтверждение не пройдено. Средства не списаны."
        case .networkBusy:       return "Сеть временно перегружена, комиссия высокая. Попробуйте позже или смените сеть."
        case .quoteExpired:      return "Курс изменился за время подтверждения. Обновите котировку."
        case .failed(let m):     return m
        }
    }

    var systemImage: String {
        switch self {
        case .insufficientFunds: return "exclamationmark.triangle.fill"
        case .canceled:          return "xmark"
        case .networkBusy:       return "wifi.exclamationmark"
        case .quoteExpired:      return "clock.arrow.circlepath"
        case .failed:            return "exclamationmark.triangle.fill"
        }
    }
}

/// Live state of a submitted crypto operation — drives ``CryptoStatusView``.
enum CryptoOutcome: Hashable, Sendable {
    case processing
    case success
    case declined(CryptoDeclineReason)

    var isProcessing: Bool { if case .processing = self { return true }; return false }
}
