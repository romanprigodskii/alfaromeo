import Foundation

/// Feature-local, **mutable** card model. The API ``Card`` is immutable (its fields are `let`), but
/// freeze / set-default / redesign / add-to-wallet / rebind all mutate card state in the demo, so the
/// Cards module owns this richer model. Hydrated from ``Card`` and from freshly-issued cards in
/// ``CardsStore``.
struct CardItem: Identifiable, Hashable, Sendable {
    let id: String
    var accountId: String
    let type: CardType
    var last4: String
    var state: CardState
    var designId: String
    var isDefault: Bool
    /// Crypto asset symbol (BTC / ETH / USDT) for crypto cards.
    var assetLink: String? = nil
    var addedToWallet: Bool = false
    var limits: CardLimits = .standard
    var issuedAt: Date? = nil
    /// Non-nil ⇒ this is a disposable / burner card (§6.1).
    var burner: BurnerConfig? = nil

    var isBurner: Bool { type == .disposable }
    var design: CardDesign { CardDesign.design(for: designId) }

    var typeLabel: String {
        switch type {
        case .virtual:    return "Виртуальная"
        case .plastic:    return "Пластиковая"
        case .crypto:     return "Крипто-карта"
        case .disposable: return "Одноразовая"
        }
    }
}

extension CardItem {
    /// Hydrate from the read-only API model.
    init(from card: Card) {
        self.init(
            id: card.id,
            accountId: card.accountId,
            type: card.type,
            last4: card.last4,
            state: card.state,
            designId: card.designId ?? Self.defaultDesignId(for: card.type),
            isDefault: card.isDefault,
            assetLink: card.assetLink,
            addedToWallet: false,
            limits: card.type == .disposable ? .burner(limit: 15_000) : .standard,
            issuedAt: nil,
            burner: nil
        )
    }

    static func defaultDesignId(for type: CardType) -> String {
        switch type {
        case .crypto:     return CardDesign.crypto.id
        case .disposable: return CardDesign.burner.id
        case .virtual, .plastic: return CardDesign.base.id
        }
    }

    // MARK: Display state

    /// True when the card cannot transact right now (chrome dims affordances).
    var isInactive: Bool { state == .frozen || state == .expired || state == .burned || state == .shipping }

    /// A short human status used in lists and banners.
    var stateLabel: String {
        switch state {
        case .active:   return isDefault ? "По умолчанию" : "Активна"
        case .frozen:   return "Заморожена"
        case .issuing:  return "Выпускается"
        case .shipping: return "В доставке"
        case .expired:  return "Истекла"
        case .burned:   return "Сожжена"
        }
    }
}

/// Demo card requisites derived deterministically from the card id — **never real PANs** (§11.8:
/// the real PAN token never leaves the server). МИР BIN `2200`; stable within a session.
struct CardRequisites: Equatable, Sendable {
    let fullPan: String
    let maskedPan: String
    let expiry: String
    let cvv: String

    init(card: CardItem) {
        let seed = Self.stableSeed(card.id)
        let mid1 = String(format: "%04d", seed % 10_000)
        let mid2 = String(format: "%04d", (seed / 7) % 10_000)
        fullPan = "2200 \(mid1) \(mid2) \(card.last4)"
        maskedPan = "2200 •••• •••• \(card.last4)"
        let month = seed % 12 + 1
        let year = 28 + seed % 5
        expiry = String(format: "%02d/%02d", month, year)
        cvv = String(format: "%03d", seed % 1_000)
    }

    /// A deterministic, process-independent fold (unlike `String.hashValue`, which is salted).
    private static func stableSeed(_ s: String) -> Int {
        s.unicodeScalars.reduce(5_381) { ($0 &* 33) ^ Int($1.value) } & 0x7FFF_FFFF
    }
}

extension CardItem {
    var requisites: CardRequisites { CardRequisites(card: self) }
}
