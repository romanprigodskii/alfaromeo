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
    /// One-line description shown under the name in the picker.
    let blurb: String
    /// Face gradient stops (top-leading → bottom-trailing).
    let gradient: [Color]
    /// Big low-opacity watermark glyph drawn on the face.
    let monogram: String
    /// Edge / accent hairline color.
    let accent: Color
    /// On-face primary text color.
    let textColor: Color
    /// Metal / embossed treatment (Infinite) — adds a brushed sheen.
    let isMetal: Bool
    /// Cold crypto/AI sheen overlay (crypto card, §13.1 cold gradient).
    let usesCryptoSheen: Bool
    /// Minimum tier required to *select* this design in the order/redesign picker.
    let requiredTier: Tier
}

extension CardDesign {
    // ── Brand-fixed card palette (local to the artwork layer) ──
    private static let graphiteTop  = Color(hex: 0x23262D)
    private static let graphiteBot  = Color(hex: 0x0C0D11)
    private static let proTop       = Color(hex: 0x2E1417)
    private static let proBot       = Color(hex: 0x100A0C)
    private static let metalTop     = Color(hex: 0x32363F)
    private static let metalBot     = Color(hex: 0x0B0C0F)
    private static let cryptoTop    = Color(hex: 0x123A4E)
    private static let cryptoBot    = Color(hex: 0x0B1E36)
    private static let bizTop       = Color(hex: 0x202C3A)
    private static let bizBot       = Color(hex: 0x0D131C)
    private static let childTop     = Color(hex: 0x3C2E78)
    private static let childBot     = Color(hex: 0x201747)
    private static let burnerTop    = Color(hex: 0x24262B)
    private static let burnerBot    = Color(hex: 0x111216)

    static let base = CardDesign(
        id: "base", name: "Графит", blurb: "Матовый графит · монограмма «A»",
        gradient: [graphiteTop, graphiteBot], monogram: "A",
        accent: BrandColors.heritageRed, textColor: BrandColors.white,
        isMetal: false, usesCryptoSheen: false, requiredTier: .base)

    static let pro = CardDesign(
        id: "pro", name: "Pro", blurb: "Насыщенный · акцент-кант",
        gradient: [proTop, proBot], monogram: "A",
        accent: BrandColors.heritageRed, textColor: BrandColors.white,
        isMetal: false, usesCryptoSheen: false, requiredTier: .pro)

    static let infinite = CardDesign(
        id: "infinite", name: "Infinite металл", blurb: "Металл · тиснение «∞»",
        gradient: [metalTop, metalBot], monogram: "∞",
        accent: BrandColors.businessPlatinum, textColor: BrandColors.white,
        isMetal: true, usesCryptoSheen: false, requiredTier: .infinite)

    static let crypto = CardDesign(
        id: "crypto", name: "Crypto", blurb: "Холодный градиент · крипто-контур",
        gradient: [cryptoTop, cryptoBot], monogram: "₿",
        accent: BrandColors.cryptoCyan, textColor: BrandColors.white,
        isMetal: false, usesCryptoSheen: true, requiredTier: .base)

    static let biz = CardDesign(
        id: "biz", name: "Бизнес", blurb: "Графит · поле сотрудника",
        gradient: [bizTop, bizBot], monogram: "R",
        accent: BrandColors.businessPlatinum, textColor: BrandColors.white,
        isMetal: false, usesCryptoSheen: false, requiredTier: .base)

    static let child = CardDesign(
        id: "child", name: "Детская", blurb: "Мягкий акцент · родительский контроль",
        gradient: [childTop, childBot], monogram: "★",
        accent: BrandColors.childViolet, textColor: BrandColors.white,
        isMetal: false, usesCryptoSheen: false, requiredTier: .base)

    static let burner = CardDesign(
        id: "burner", name: "Одноразовая", blurb: "Эфемерный токен · авто-сжигание",
        gradient: [burnerTop, burnerBot], monogram: "#",
        accent: BrandColors.warningDark, textColor: BrandColors.white,
        isMetal: false, usesCryptoSheen: false, requiredTier: .base)

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
