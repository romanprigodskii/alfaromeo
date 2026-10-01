import SwiftUI

// MARK: - Recipient

/// A finalized transfer recipient, assembled by whichever recipient step ran. Decouples the
/// confirm/status steps from each rail's input specifics (§10.3).
struct Recipient: Hashable {
    var name: String
    var detail: String            // masked phone / card / account / wallet — the secondary line
    var icon: String
    var bank: String? = nil       // for СБП — the receiving bank
    var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return parts.isEmpty ? "·" : parts.map(String.init).joined().uppercased()
    }
}

// MARK: - Contacts (СБП / crypto)

/// A person in the user's contacts — payable by phone (СБП) or by crypto-перевод (§10.3).
struct PaymentContact: Identifiable, Hashable {
    let id: String
    let name: String
    let phone: String
    let bank: String              // their default СБП bank
    var hasWallet: Bool = true    // false → crypto send shows "инвайт + авто-создание кошелька"
    var walletShort: String? = nil

    var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return parts.isEmpty ? "·" : parts.map(String.init).joined().uppercased()
    }

    /// Build the rail-agnostic recipient for an СБП transfer.
    func sbpRecipient() -> Recipient {
        Recipient(name: name, detail: phone, icon: "person.fill", bank: bank)
    }

    /// Build the recipient for a crypto-перевод (shows wallet or invite hint).
    func cryptoRecipient() -> Recipient {
        Recipient(name: name,
                  detail: hasWallet ? (walletShort ?? phone) : "Пригласить · авто-кошелёк",
                  icon: "bitcoinsign.circle.fill")
    }
}

// MARK: - Billers (ЖКУ / штрафы / поставщики / мои платежи)

/// A payable biller — utilities, fines, a supplier, or a saved "мой платёж". Reuses the transfer
/// flow with a prefilled recipient (§9.2 «Платежи поставщикам», плитки ЖКУ/Штрафы).
struct Biller: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String            // лицевой счёт / УИН / ИНН — secondary line
    let icon: String
    var categoryId: String? = nil
    var suggestedAmount: Double? = nil   // prefilled (e.g. начисление ЖКУ / сумма штрафа)
    var tintHex: UInt32? = nil

    func recipient() -> Recipient {
        Recipient(name: name, detail: detail, icon: icon)
    }
}

/// A supplier category chip (§9.2 «категории» on the suppliers screen).
struct BillerCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
}

/// The three biller hubs that share ``BillerListView``.
enum BillerSection: String, Hashable, Identifiable {
    case myPayments, utilities, fines
    var id: String { rawValue }

    var title: String {
        switch self {
        case .myPayments: return "Мои платежи"
        case .utilities:  return "Счета ЖКУ"
        case .fines:      return "Штрафы ГАИ"
        }
    }
    var icon: String {
        switch self {
        case .myPayments: return "star.fill"
        case .utilities:  return "house.fill"
        case .fines:      return "car.fill"
        }
    }
    var blurb: String {
        switch self {
        case .myPayments: return "Сохранённые получатели и недавние платежи."
        case .utilities:  return "Начисления ЖКУ по вашему адресу."
        case .fines:      return "Штрафы по номеру авто и водительскому."
        }
    }
}

// MARK: - Offers / templates / autopayments

/// An offer on the payments hub (§9.2), shown as a plain row.
struct PaymentOffer: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
}

/// A saved transfer template (§9.2 «Шаблоны»).
struct PaymentTemplate: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let kind: TransferKind
    var amount: Double? = nil
    var icon: String { kind.icon }
}

/// A scheduled recurring payment (§9.2 «Автоплатежи»).
struct Autopayment: Identifiable, Hashable {
    enum Schedule: String, CaseIterable, Hashable {
        case monthly, weekly, byThreshold
        var label: String {
            switch self {
            case .monthly:     return "Ежемесячно"
            case .weekly:      return "Еженедельно"
            case .byThreshold: return "При остатке < порога"
            }
        }
    }
    let id: String
    var title: String
    var detail: String
    var amount: Double
    var schedule: Schedule
    var nextDate: String
    var isOn: Bool = true
    var icon: String = "arrow.triangle.2.circlepath"
}

// MARK: - Operation outcome (animated status, §9.2 / §10.3)

/// Why an operation was declined on the animated status step. Limits and the неквал-инвестор cap are
/// handled *pre-flight* as non-dead-end inline gates (``LimitGateCard``), not as status declines — so
/// the only two reasons that reach the status screen are these. The `insufficientFunds` copy mirrors
/// the reference («Проверьте, достаточно ли денег…»); `canceled` is the «отмена» edge case.
enum DeclineReason: Hashable {
    case insufficientFunds
    case canceled
    case failed(String)   // a backend error surfaced verbatim (friendly text), e.g. recipient not found

    var title: String {
        switch self {
        case .insufficientFunds: return "Операция отклонена"
        case .canceled:          return "Операция отменена"
        case .failed:            return "Не удалось перевести"
        }
    }

    var message: String {
        switch self {
        case .insufficientFunds:
            return "Проверьте, достаточно ли денег на счёте, и попробуйте снова."
        case .canceled:
            return "Подтверждение не пройдено. Средства не списаны."
        case .failed(let m):
            return m
        }
    }

    var systemImage: String {
        switch self {
        case .insufficientFunds: return "exclamationmark.triangle.fill"
        case .canceled:          return "xmark"
        case .failed:            return "exclamationmark.triangle.fill"
        }
    }
}

/// The live state of a submitted operation — drives ``OperationStatusView`` (§13.1 animated statuses).
enum OperationOutcome: Hashable {
    case processing
    case success
    case declined(DeclineReason)
}

// MARK: - AccountType display (Core type — extended locally for Payments)

extension AccountType {
    var paymentsLabel: String {
        switch self {
        case .current:      return "Текущий счёт"
        case .savings:      return "Накопительный"
        case .crypto:       return "Крипто-кошелёк"
        case .digitalRuble: return "Цифровой рубль"
        }
    }
    var paymentsIcon: String {
        switch self {
        case .current:      return "banknote.fill"
        case .savings:      return "chart.line.uptrend.xyaxis"
        case .crypto:       return "bitcoinsign.circle.fill"
        case .digitalRuble: return "rublesign.circle.fill"
        }
    }
}

extension Account {
    /// Display symbol for the account's currency (₽ for fiat / цифр.₽, ticker otherwise).
    var symbol: String { currency == "RUB" ? "₽" : currency }
    var isRubLike: Bool { currency == "RUB" }
    var displayTitle: String { type == .current && !isRubLike ? "Валютный счёт" : type.paymentsLabel }
    var displaySubtitle: String { "·· \(id.suffix(4)) · \(currency)" }
}
