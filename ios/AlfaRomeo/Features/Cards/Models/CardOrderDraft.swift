import Foundation

/// The product chosen in step 1 of the order flow (§6.2 "дебет/кредит/крипто/одноразовая").
/// Maps to a ``CardType`` form factor: debit/credit → virtual; crypto → crypto; one-time → disposable.
enum CardProduct: String, CaseIterable, Identifiable, Sendable {
    case debit, credit, crypto, disposable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .debit:      return "Дебетовая"
        case .credit:     return "Кредитная"
        case .crypto:     return "Крипто-карта"
        case .disposable: return "Одноразовая"
        }
    }

    var subtitle: String {
        switch self {
        case .debit:      return "Виртуальная мгновенно, привязка к счёту"
        case .credit:     return "Льготный период, виртуальная сразу"
        case .crypto:     return "Оплата криптой, продавец получает рубли"
        case .disposable: return "Под одну покупку, сгорает сама"
        }
    }

    var icon: String {
        switch self {
        case .debit:      return "creditcard"
        case .credit:     return "creditcard.and.123"
        case .crypto:     return "bitcoinsign.circle"
        case .disposable: return "flame"
        }
    }

    /// The card form factor that gets issued for this product.
    var cardType: CardType {
        switch self {
        case .debit, .credit: return .virtual
        case .crypto:         return .crypto
        case .disposable:     return .disposable
        }
    }

    /// Burners are virtual-only; everything else can additionally order a plastic (§6.2).
    var allowsPlastic: Bool { self != .disposable }

    /// Binds to a crypto wallet/asset rather than a fiat account.
    var bindsToCrypto: Bool { self == .crypto }
}

/// How a disposable / burner card auto-expires (§6.1).
enum BurnerMode: String, CaseIterable, Identifiable, Sendable {
    case singleUse, merchantLock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singleUse:    return "Одноразовый номер"
        case .merchantLock: return "Привязка к мерчанту"
        }
    }

    var detail: String {
        switch self {
        case .singleUse:    return "Сгорает после первой успешной операции"
        case .merchantLock: return "Работает только у одного мерчанта"
        }
    }

    var icon: String {
        switch self {
        case .singleUse:    return "1.circle"
        case .merchantLock: return "lock.circle"
        }
    }
}

/// Config attached to a disposable card; mirrored to ``CardItem.burner``.
struct BurnerConfig: Equatable, Hashable, Sendable {
    var mode: BurnerMode
    var merchant: String?
    var limit: Double
    /// True once the single-use number has been spent / the card has been burned.
    var used: Bool = false

    var statusLabel: String {
        if used { return "Сожжена" }
        switch mode {
        case .singleUse:    return "Активна · одноразовая"
        case .merchantLock: return "Активна · \(merchant ?? "мерчант")"
        }
    }
}

/// Mutable wizard state for the order flow (§6.2). One per ``CardOrderView`` session.
struct CardOrderDraft: Equatable {
    var product: CardProduct = .debit
    var designId: String = CardDesign.base.id
    /// Fiat account binding (debit / credit).
    var accountId: String?
    /// Crypto asset binding (crypto card).
    var asset: String?

    // ── Physical delivery ──
    var address: String = ""
    var method: DeliveryMethod = .courier

    // ── Burner ──
    var burnerMode: BurnerMode = .singleUse
    var burnerMerchant: String = ""
    var burnerLimit: Double = 15_000
}
