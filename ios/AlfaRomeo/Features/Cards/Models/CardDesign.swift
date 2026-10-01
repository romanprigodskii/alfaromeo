import SwiftUI

/// Visual identity for a card face (§13.2 tier line: Base / Pro / Infinite / Crypto / Business).
///
/// Card artwork is **brand-fixed** — a physical card's design does not re-theme with the active
/// profile — so this reaches for `BrandColors` primitives directly, unlike app chrome which reads
/// `theme.*`. The catalog also encodes which tier may *choose* each design (picker gating, §6.3).
struct CardDesign: Identifiable, Hashable, Sendable {
    let id: String
    /// Human label for the design picker.
    let name: String
    /// One-line fact shown under the name in the picker (who can pick it).
    let blurb: String
    /// Flat face colour (docs/DESIGN.md §5 card art: flat, ≤4% vertical shade, no gloss).
    let face: Color
    /// On-face text colour.
    let textColor: Color
    /// Minimum tier required to *select* this design in the order/redesign picker.
    let requiredTier: Tier
}

extension CardDesign {
    // Brand-fixed card faces, aligned with ``CardArt`` so a card reads the same on Home and here:
    // personal red, business graphite, premium / crypto ink, child violet.
    private static let warmGraphite = Color(hex: 0x3A3634)
    private static let graphite     = Color(hex: 0x2E333B)
    private static let ink          = Color(hex: 0x1A1818)
    private static let ash          = Color(hex: 0x4A4645)

    static let base = CardDesign(
        id: "base", name: "Графит", blurb: "Любой тариф",
        face: warmGraphite, textColor: BrandColors.white, requiredTier: .base)

    static let pro = CardDesign(
        id: "pro", name: "Pro", blurb: "С тарифа Pro",
        face: BrandColors.heritageRedLight, textColor: BrandColors.white, requiredTier: .pro)

    static let infinite = CardDesign(
        id: "infinite", name: "Infinite", blurb: "С тарифа Infinite",
        face: ink, textColor: BrandColors.white, requiredTier: .infinite)

    static let crypto = CardDesign(
        id: "crypto", name: "Crypto", blurb: "Крипто-карта, любой тариф",
        face: ink, textColor: BrandColors.white, requiredTier: .base)

    static let biz = CardDesign(
        id: "biz", name: "Бизнес", blurb: "Бизнес-профиль",
        face: graphite, textColor: BrandColors.white, requiredTier: .base)

    static let child = CardDesign(
        id: "child", name: "Детская", blurb: "Детский профиль",
        face: BrandColors.childVioletLight, textColor: BrandColors.white, requiredTier: .base)

    static let burner = CardDesign(
        id: "burner", name: "Одноразовая", blurb: "Сгорает после использования",
        face: ash, textColor: BrandColors.white, requiredTier: .base)

    /// Every design, in catalog order.
    static let all: [CardDesign] = [base, pro, infinite, crypto, biz, child, burner]

    /// Resolve a design id (falls back to ``base`` for unknown / nil ids).
    static func design(for id: String?) -> CardDesign {
        all.first { $0.id == id } ?? base
    }

    /// The selectable designs for a product at a tier (order step 2 / redesign sheet).
    /// Crypto product → the crypto design only; otherwise the personal tier line up to the tier,
    /// always including the crypto card as an option (it's a product, not a tier perk).
    static func options(for product: CardProduct, tier: Tier) -> [CardDesign] {
        switch product {
        case .crypto:
            return [crypto]
        case .disposable:
            return [burner]
        case .debit, .credit:
            let line = [base, pro, infinite].filter { tier.rank >= $0.requiredTier.rank }
            return line + [crypto]
        }
    }

    /// Designs a user may switch an existing card to, given its type + the active tier.
    static func redesignOptions(for type: CardType, tier: Tier) -> [CardDesign] {
        switch type {
        case .crypto:     return [crypto]
        case .disposable: return [burner]
        case .virtual, .plastic:
            return [base, pro, infinite].filter { tier.rank >= $0.requiredTier.rank }
        }
    }
}
