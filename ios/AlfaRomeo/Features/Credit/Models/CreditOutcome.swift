import Foundation

/// Terminal state of a credit application → drives ``CreditStatusView`` (§10.5), mirroring the
/// Payments/Savings status language: обработка → одобрено / отказ + причина.
enum CreditOutcome: Equatable {
    case processing
    case success
    case declined(CreditDecline)
}

/// Why an application was declined — each carries demo copy, a «что улучшить» hint (§10.5 edge:
/// «отказ с причиной + что улучшить»), and an SF Symbol for the status medallion.
enum CreditDecline: Equatable {
    case overDebtLoad          // ПДН выше порога — нет свободного платежа
    case thinFile              // скоринг/история ниже порога
    case noConsent             // не даны обязательные согласия
    case canceled              // биометрия отменена

    var title: String {
        switch self {
        case .overDebtLoad: return "Высокая долговая нагрузка"
        case .thinFile:     return "Недостаточно истории"
        case .noConsent:    return "Нужны согласия"
        case .canceled:     return "Подтверждение отменено"
        }
    }

    var message: String {
        switch self {
        case .overDebtLoad:
            return "Текущие платежи уже близки к половине дохода — свободного платежа под новый кредит почти не осталось."
        case .thinFile:
            return "По данным БКИ пока мало истории, чтобы оценить риск. Это поправимо."
        case .noConsent:
            return "Без согласия на запрос в БКИ и обработку данных оформить кредит нельзя."
        case .canceled:
            return "Подтверждение биометрией не пройдено. Попробуйте ещё раз."
        }
    }

    /// «Что улучшить» — the actionable next step shown under a decline (§10.5).
    var improvement: String {
        switch self {
        case .overDebtLoad: return "Закройте кредитную карту или микрозайм и вернитесь — лимит откроется. Откройте симулятор, чтобы увидеть, насколько."
        case .thinFile:     return "Пользуйтесь картой и гасите платежи вовремя 3–6 месяцев — скоринг подрастёт."
        case .noConsent:    return "Вернитесь к шагу согласий и отметьте обязательные пункты."
        case .canceled:     return "Повторите подтверждение Face ID или введите код устройства."
        }
    }

    var systemImage: String {
        switch self {
        case .overDebtLoad: return "gauge.with.dots.needle.bottom.50percent"
        case .thinFile:     return "doc.text.magnifyingglass"
        case .noConsent:    return "checkmark.shield"
        case .canceled:     return "xmark.circle"
        }
    }

    /// The decline framing handed to the AI copilot when the user taps «Спросить у AI» (§10.9).
    var copilotReason: String { title }
}
