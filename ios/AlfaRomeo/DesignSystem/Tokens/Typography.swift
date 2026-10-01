import SwiftUI

/// Typography tokens (docs/DESIGN.md §3). One family: SF Pro. No `.heavy` / `.black`.
/// Numbers use tabular figures; true monospace (SF Mono) only for card numbers, crypto addresses and
/// requisites, via ``code(_:weight:)``.
///
/// Every size is anchored to the nearest Dynamic Type text style, so text scales with the user's
/// Larger Text setting while the hierarchy holds.
///
/// Role → token:
/// | role (DESIGN §3)   | token                                  |
/// |--------------------|----------------------------------------|
/// | largeTitle 34 bold | `largeTitle` (legacy: `displayL`)      |
/// | hero amount 40 sb  | `heroAmount` / `heroKopecks` (26 sb)   |
/// | title1 28 bold     | `title1`                               |
/// | title2 22 bold     | `title2` (legacy: `title`)             |
/// | headline 17 sb     | `headline`                             |
/// | body 17            | `bodyM`, `body()`                      |
/// | callout 16         | `callout`                              |
/// | subheadline 15     | `subheadline`                          |
/// | footnote 13        | `footnote` (legacy: `caption`)         |
/// | caption 12 medium  | `micro`                                |
enum BrandFont {
    // MARK: Faces (the single swap point)

    /// Heading face. Weight is clamped to `.bold` at most (no heavy/black display type).
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(textStyle(for: size), design: .default).weight(clamped(weight, max: .bold))
    }

    /// Body / UI text face.
    static func body(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font {
        .system(textStyle(for: size), design: .default).weight(clamped(weight, max: .bold))
    }

    /// Numeric face: SF Pro with **tabular figures** (not a monospaced font). Historically this was SF
    /// Mono; the numbers-in-mono look is retired (DESIGN §3), so every existing `mono(...)` amount now
    /// renders as clean tabular SF Pro. Weight is clamped to `.semibold` (hero amounts are semibold).
    /// For card numbers, addresses and requisites use ``code(_:weight:)``.
    static func mono(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font {
        .system(textStyle(for: size), design: .default)
            .weight(clamped(weight, max: .semibold))
            .monospacedDigit()
    }

    /// True monospace (SF Mono): card numbers, crypto addresses, requisites (ИНН, БИК, счёт) only.
    static func code(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(textStyle(for: size), design: .monospaced).weight(clamped(weight, max: .semibold))
    }

    /// Monetary amounts: SF Pro, tabular figures, at most semibold.
    static func amountFace(_ size: CGFloat = 28, weight: Font.Weight = .semibold) -> Font {
        .system(textStyle(for: size), design: .default)
            .weight(clamped(weight, max: .semibold))
            .monospacedDigit()
    }

    /// Map a nominal point size to the closest Dynamic Type text style (the scaling anchor).
    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 38...:        return .largeTitle   // ~34 base
        case 27..<38:      return .title         // ~28
        case 21..<27:      return .title2        // ~22
        case 19..<21:      return .title3        // ~20
        case 16.5..<19:    return .body          // ~17
        case 15.5..<16.5:  return .callout       // ~16
        case 14..<15.5:    return .subheadline   // ~15
        case 12.5..<14:    return .footnote      // ~13
        case 11.5..<12.5:  return .caption       // ~12
        default:           return .caption2      // ~11
        }
    }

    /// Caps a weight (heavy / black are not part of the system).
    private static func clamped(_ weight: Font.Weight, max cap: Font.Weight) -> Font.Weight {
        let order: [Font.Weight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        guard let w = order.firstIndex(of: weight), let c = order.firstIndex(of: cap) else { return weight }
        return w > c ? cap : weight
    }

    // MARK: Roles (DESIGN §3)

    /// 34 bold: screen title.
    static let largeTitle  = display(34)
    /// 28 bold: sheet titles, result screens.
    static let title1      = display(28)
    /// 22 bold: THE section header style.
    static let title2      = display(22)
    /// 17 semibold: emphasized row titles, buttons.
    static let headline    = body(17, weight: .semibold)
    /// 16 regular: secondary row text.
    static let callout     = body(16)
    /// 15 regular: row subtitles, metadata.
    static let subheadline = body(15)
    /// 13 regular: captions, legal, timestamps.
    static let footnote    = body(13)
    /// 40 semibold tabular: the one main balance per screen (integer part).
    static let heroAmount  = amountFace(40)
    /// 26 semibold tabular: the kopecks / currency part of a hero balance.
    static let heroKopecks = amountFace(26)

    // MARK: Legacy names (kept source-compatible, retuned to the scale above)

    /// = hero amount (40 semibold).
    static let displayXL = heroAmount
    /// = largeTitle (34 bold).
    static let displayL  = largeTitle
    /// = title2 (22 bold), the section header.
    static let title     = title2
    /// = body (17 regular).
    static let bodyM     = body(17)
    /// = footnote (13 regular).
    static let caption   = footnote
    /// = caption role (12 medium): badges, chart axes.
    static let micro     = body(12, weight: .medium)
    /// 28 semibold tabular.
    static let amount    = amountFace(28)
    /// 17 medium tabular: trailing row values.
    static let amountS   = amountFace(17, weight: .medium)
}
