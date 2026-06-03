import SwiftUI

/// The seven transfer rails of §9.2 / §10.3. Drives the unified ``TransferFlowView`` — each kind
/// declares its recipient-entry style, whether it moves crypto (₽-эквивалент + неквал-лимит), and
/// its display chrome. Bill payments (ЖКУ / штрафы / поставщики) reuse the same flow via a prefilled
/// ``Biller``, so this enum stays focused on the person-to-person / account / crypto rails.
enum TransferKind: String, Hashable, CaseIterable, Identifiable {
    case betweenAccounts
    case byPhone
    case byCard
    case byRequisites
    case abroad
    case cryptoToContact
    case digitalRubleQR

    var id: String { rawValue }

    /// How the recipient is entered for this rail (drives the first flow step).
    enum RecipientStyle {
        case accounts        // destination is one of the user's own accounts
        case phoneContact    // СБП — pick/enter a phone contact
        case cryptoContact   // crypto to a contact by phone, with asset + ₽-эквивалент
        case cardNumber      // 16-digit PAN
        case requisites      // счёт + БИК + ИНН + получатель
        case abroad          // страна + IBAN/SWIFT
        case qr              // цифровой рубль — универсальный QR / C2C
    }

    var title: String {
        switch self {
        case .betweenAccounts: return "Между счетами"
        case .byPhone:         return "По телефону"
        case .byCard:          return "По номеру карты"
        case .byRequisites:    return "По реквизитам"
        case .abroad:          return "За рубеж"
        case .cryptoToContact: return "Крипто-перевод"
        case .digitalRubleQR:  return "Цифровым рублём"
        }
    }

    var subtitle: String {
        switch self {
        case .betweenAccounts: return "Свои счета и кошельки"
        case .byPhone:         return "СБП · мгновенно"
        case .byCard:          return "В любой банк"
        case .byRequisites:    return "Юр- и физлицам"
        case .abroad:          return "Через ЭПР · ₽/стейбл"
        case .cryptoToContact: return "Контакту по номеру"
        case .digitalRubleQR:  return "Универсальный QR"
        }
    }

    var icon: String {
        switch self {
        case .betweenAccounts: return "arrow.left.arrow.right"
        case .byPhone:         return "phone.fill"
        case .byCard:          return "creditcard"
        case .byRequisites:    return "doc.text"
        case .abroad:          return "globe"
        case .cryptoToContact: return "bitcoinsign.circle.fill"
        case .digitalRubleQR:  return "qrcode"
        }
    }

    var recipientStyle: RecipientStyle {
        switch self {
        case .betweenAccounts: return .accounts
        case .byPhone:         return .phoneContact
        case .byCard:          return .cardNumber
        case .byRequisites:    return .requisites
        case .abroad:          return .abroad
        case .cryptoToContact: return .cryptoContact
        case .digitalRubleQR:  return .qr
        }
    }

    /// Crypto rail: amount carries a ₽-эквивалент by mock rate and counts against the неквал-лимит.
    var isCrypto: Bool { self == .cryptoToContact }

    /// Cold crypto/AI gradient (§13.1) for the "future money" rails — visually separates from fiat.
    var usesCryptoGradient: Bool { self == .cryptoToContact || self == .digitalRubleQR }

    /// The verb shown on the confirm button.
    var actionVerb: String { isCrypto ? "Отправить" : "Перевести" }
}
