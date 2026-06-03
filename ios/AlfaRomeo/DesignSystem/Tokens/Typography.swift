import SwiftUI

/// Typography tokens (§13.1): strong grotesk display, neutral body, monospaced numerals.
///
/// Currently mapped to the system faces (SF / SF Mono). To swap in a custom grotesk later, change
/// only the three face factories below — every role token flows through them.
enum BrandFont {
    // MARK: Faces (the single swap point)
    //
    // Each requested point size is anchored to the nearest Dynamic Type text style, so the system
    // font scales with the user's Larger Text setting (WCAG 1.4.4) while preserving the type
    // hierarchy. A custom grotesk can later be dropped in via `Font.custom(_:size:relativeTo:)`
    // by changing only these three factories.

    /// Strong grotesk face for display / headings. (System: heavy SF.)
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(textStyle(for: size), design: .default).weight(weight)
    }

    /// Neutral face for body / UI text. (System: SF.)
    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(textStyle(for: size), design: .default).weight(weight)
    }

    /// Monospaced face for amounts, rates, crypto addresses. (System: SF Mono.)
    static func mono(_ size: CGFloat = 16, weight: Font.Weight = .medium) -> Font {
        .system(textStyle(for: size), design: .monospaced).weight(weight)
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
        case 12.5..<14:    return .footnote       // ~13
        case 11.5..<12.5:  return .caption        // ~12
        default:           return .caption2      // ~11
        }
    }

    // MARK: Role tokens (use these in components)

    static let displayXL = display(40)
    static let displayL  = display(32)
    static let title     = display(22, weight: .bold)
    static let headline  = body(17, weight: .semibold)
    static let bodyM     = body(16)
    static let callout   = body(15)
    static let caption   = body(13)
    static let micro     = body(11, weight: .medium)
    static let amount    = mono(28, weight: .semibold)
    static let amountS   = mono(17, weight: .medium)
}
