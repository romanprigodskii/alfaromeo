import SwiftUI
import UIKit

extension Color {
    /// Hex initializer, e.g. `Color(hex: 0xD3140F)`.
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// WCAG relative luminance (linearized sRGB).
    var relativeLuminance: Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    /// Best-contrast text color (ink or white) for content drawn on top of this color, chosen by the
    /// higher actual WCAG contrast ratio (not a luminance threshold).
    var bestOnColor: Color {
        let bg = relativeLuminance
        func ratio(_ a: Double, _ b: Double) -> Double { (max(a, b) + 0.05) / (min(a, b) + 0.05) }
        let ink = BrandColors.inkOnLight.relativeLuminance
        let white = 1.0
        return ratio(bg, ink) >= ratio(bg, white) ? BrandColors.inkOnLight : BrandColors.white
    }
}

/// Raw color palette, the primitive layer (docs/DESIGN.md §2). UI reads semantic tokens through
/// ``Theme`` (`@Environment(\.theme)`), never `BrandColors.*` directly.
///
/// Strategy: tinted neutrals with a hair of warmth toward the brand red, plus ONE accent per profile
/// context. No pure `#000` / `#FFF` for surfaces or text. Light is primary; dark is supported.
enum BrandColors {
    // ── Neutrals · light (primary) ──
    static let paper          = Color(hex: 0xF3F2F1)  // background
    static let surfaceLight   = Color(hex: 0xFDFCFC)  // surface: grouped lists, sheets
    static let elevatedLight  = Color(hex: 0xF8F7F6)  // elevated: inputs, nested controls
    static let fillLight      = Color(hex: 0xECEAE8)  // fill: neutral control bg, glyph circles
    static let borderLight    = Color(hex: 0xE6E3E1)  // hairlines
    static let inkOnLight     = Color(hex: 0x141213)  // text primary
    static let mutedOnLight   = Color(hex: 0x6E6A69)  // text secondary
    static let faintOnLight   = Color(hex: 0xA39E9C)  // text tertiary: placeholders, disabled

    // ── Neutrals · dark ──
    static let nearBlack      = Color(hex: 0x0E0D0D)  // background
    static let graphite900    = Color(hex: 0x1A1818)  // surface
    static let graphite800    = Color(hex: 0x232120)  // elevated
    static let fillDark       = Color(hex: 0x2A2726)  // fill
    static let graphite700    = Color(hex: 0x2E2B2A)  // border / hairline
    static let inkOnDark      = Color(hex: 0xF4F2F1)  // text primary
    static let mutedOnDark    = Color(hex: 0x9C9795)  // text secondary
    static let faintOnDark    = Color(hex: 0x6A6563)  // text tertiary

    // ── Business · cool graphite BASE (a distinct context, not only a different accent) ──
    static let bizBgDark        = Color(hex: 0x0F141C)
    static let bizSurfaceDark   = Color(hex: 0x17202B)
    static let bizElevatedDark  = Color(hex: 0x212C3A)
    static let bizFillDark      = Color(hex: 0x263241)
    static let bizBorderDark    = Color(hex: 0x303C4D)
    static let bizBgLight       = Color(hex: 0xE9ECF0)
    static let bizSurfaceLight  = Color(hex: 0xFCFDFD)
    static let bizElevatedLight = Color(hex: 0xF3F5F8)
    static let bizFillLight     = Color(hex: 0xE1E5EA)
    static let bizBorderLight   = Color(hex: 0xD8DEE5)

    // ── Accents · per profile context ──
    static let heritageRed       = Color(hex: 0xF0302A)  // personal accent (dark)
    static let heritageRedLight  = Color(hex: 0xD3140F)  // personal accent (light)
    static let businessPlatinum  = Color(hex: 0xB8C0CC)  // business accent (dark)
    static let businessGraphite  = Color(hex: 0x363B44)  // business accent (light)
    static let childViolet       = Color(hex: 0x8C6BFF)  // child accent (dark)
    static let childVioletLight  = Color(hex: 0x6E49F0)  // child accent (light)
    static let jointTeal         = Color(hex: 0x2BD4C0)  // joint accent (dark)
    static let jointTealLight    = Color(hex: 0x0E8E80)  // joint accent (light)

    // ── Legacy crypto stops ──
    // Retired by DESIGN.md §2 («crypto has no special colour»). Kept only so `theme.accentCrypto` /
    // `theme.cryptoGradient` call sites keep compiling until the crypto module is redesigned.
    static let cryptoBlue    = Color(hex: 0x4F7CFF)
    static let cryptoCyan    = Color(hex: 0x19D3E0)

    // ── Status · dark ──
    static let successDark   = Color(hex: 0x34C77B)
    static let dangerDark    = Color(hex: 0xF5455C)
    static let warningDark   = Color(hex: 0xF2B441)
    // ── Status · light ──
    static let successLight  = Color(hex: 0x147F48)
    static let dangerLight   = Color(hex: 0xD3142E)
    static let warningLight  = Color(hex: 0xB87708)
    // ── Status · light "ink" (AA-safe as TEXT on a pale status tint) ──
    static let successInkLight = Color(hex: 0x0A6B3A)
    static let dangerInkLight  = Color(hex: 0xB3162E)
    static let warningInkLight = Color(hex: 0x7A5200)

    // ── Absolutes (for content on the accent or on card art only) ──
    static let white         = Color(hex: 0xFFFFFF)
    static let black         = Color(hex: 0x000000)
}
