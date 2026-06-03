import SwiftUI
import UIKit

extension Color {
    /// Hex initializer, e.g. `Color(hex: 0xE2120F)`.
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

    /// Best-contrast text color (near-black ink or white) for content drawn on top of this color —
    /// chosen by the higher actual WCAG contrast ratio (not a luminance threshold), so it picks
    /// dark text on mid/light tints like platinum/cyan/amber where white would fail AA.
    var bestOnColor: Color {
        let bg = relativeLuminance
        func ratio(_ a: Double, _ b: Double) -> Double { (max(a, b) + 0.05) / (min(a, b) + 0.05) }
        let ink = BrandColors.inkOnLight.relativeLuminance   // ≈ 0.003
        let white = 1.0
        return ratio(bg, ink) >= ratio(bg, white) ? BrandColors.inkOnLight : BrandColors.white
    }
}

/// Raw color palette — the primitive layer. Semantic, theme-aware usage goes through ``Theme``;
/// UI code reads `theme.*`, not `BrandColors.*`. Light is the primary scheme; dark is supported (§13.1).
enum BrandColors {
    // ── Neutrals · dark ──
    static let nearBlack     = Color(hex: 0x0A0A0B)   // background
    static let graphite900   = Color(hex: 0x141518)   // surface
    static let graphite800   = Color(hex: 0x1E2025)   // elevated
    static let graphite700   = Color(hex: 0x2B2D34)   // border / hairline
    static let inkOnDark      = Color(hex: 0xF7F7F8)  // text primary
    static let mutedOnDark    = Color(hex: 0x9A9CA3)  // text secondary

    // ── Neutrals · light ──
    static let paper          = Color(hex: 0xF4F4F6)  // background
    static let surfaceLight   = Color(hex: 0xFFFFFF)  // surface
    static let elevatedLight  = Color(hex: 0xFBFBFD)  // elevated
    static let borderLight    = Color(hex: 0xE4E5EA)  // border / hairline
    static let inkOnLight     = Color(hex: 0x0B0B0D)  // text primary
    static let mutedOnLight   = Color(hex: 0x6B6D75)  // text secondary

    // ── Business · graphite BASE (§8/§13.1: бизнес — графитовая тема, not just an accent) ──
    // Cool, blue-tinted graphite surfaces so the business mode reads as a distinct context.
    static let bizBgDark       = Color(hex: 0x0F141C)   // background
    static let bizSurfaceDark  = Color(hex: 0x17202B)   // surface
    static let bizElevatedDark = Color(hex: 0x212C3A)   // elevated
    static let bizBorderDark   = Color(hex: 0x303C4D)   // border
    static let bizBgLight       = Color(hex: 0xE7EBF0)  // cool steel paper
    static let bizSurfaceLight  = Color(hex: 0xFFFFFF)
    static let bizElevatedLight = Color(hex: 0xF2F5F9)
    static let bizBorderLight   = Color(hex: 0xD3DAE3)

    // ── Accents · per profile context (§5.2, §13.1) ──
    static let heritageRed       = Color(hex: 0xE2120F)  // personal — heritage accent (dark)
    static let heritageRedLight  = Color(hex: 0xC60F0C)  // personal accent on a light bg
    static let businessPlatinum  = Color(hex: 0xB8C0CC)  // business — graphite/steel accent (dark)
    static let businessGraphite  = Color(hex: 0x363B44)  // business accent on a light bg
    static let childViolet       = Color(hex: 0x8C6BFF)  // child — soft accent (dark)
    static let childVioletLight  = Color(hex: 0x6E49F0)  // child accent on a light bg
    static let jointTeal         = Color(hex: 0x2BD4C0)  // joint/family — distinct accent (dark)
    static let jointTealLight    = Color(hex: 0x0E8E80)  // joint accent on a light bg

    // ── Crypto / AI · cold gradient (visually separates from fiat, §13.1) ──
    static let cryptoBlue    = Color(hex: 0x4F7CFF)
    static let cryptoCyan    = Color(hex: 0x19D3E0)

    // ── Status · dark ──
    static let successDark   = Color(hex: 0x2ED27A)
    static let dangerDark    = Color(hex: 0xF5455C)
    static let warningDark   = Color(hex: 0xF2B441)
    // ── Status · light ──
    static let successLight  = Color(hex: 0x16A35C)
    static let dangerLight   = Color(hex: 0xD81E37)
    static let warningLight  = Color(hex: 0xC9820A)
    // ── Status · light "ink" (AA-safe as TEXT on a pale status tint over paper) ──
    static let successInkLight = Color(hex: 0x0A6B3A)
    static let dangerInkLight  = Color(hex: 0xB3162E)
    static let warningInkLight = Color(hex: 0x7A5200)

    // ── Absolutes (for on-accent text) ──
    static let white         = Color(hex: 0xFFFFFF)
    static let black         = Color(hex: 0x000000)
}
