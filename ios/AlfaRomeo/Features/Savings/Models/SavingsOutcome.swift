import Foundation

/// Terminal state of opening a вклад / placing a стейк → drives ``SavingsStatusView`` (§10.6),
/// mirroring the Payments operation-status language (§9.2): обработка → успех / отклонено + причина.
enum SavingsOutcome: Equatable {
    case processing
    case success
    case declined(SavingsDecline)
}

/// Why an open/stake was declined — each carries demo copy + an SF Symbol for the status medallion.
enum SavingsDecline: Equatable {
    case insufficientFunds
    case riskNotAccepted        // обязательный чекбокс риска не отмечен (§10.6)
    case overLimit              // лимит неквал-инвестора 300 тыс ₽/год (§2.4)
    case canceled               // биометрия отменена

    var title: String {
        switch self {
        case .insufficientFunds: return "Недостаточно средств"
        case .riskNotAccepted:   return "Нужно подтвердить риск"
        case .overLimit:         return "Превышен лимит инвестора"
        case .canceled:          return "Операция отменена"
        }
    }

    var message: String {
        switch self {
        case .insufficientFunds:
            return "На счёте недостаточно средств для этой суммы. Уменьшите сумму или пополните счёт."
        case .riskNotAccepted:
            return "Стейкинг не застрахован АСВ. Отметьте согласие с рыночным риском, чтобы продолжить."
        case .overLimit:
            return "Для неквалифицированного инвестора лимит — 300 000 ₽ в год (§2.4). Уменьшите сумму или повысьте статус."
        case .canceled:
            return "Подтверждение биометрией не пройдено. Попробуйте ещё раз."
        }
    }

    var systemImage: String {
        switch self {
        case .insufficientFunds: return "rublesign.circle"
        case .riskNotAccepted:   return "checkmark.shield"
        case .overLimit:         return "gauge.with.dots.needle.bottom.50percent"
        case .canceled:          return "xmark.circle"
        }
    }
}
