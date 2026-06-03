import SwiftUI

/// Resolved, semantic color theme for the current profile context + color scheme.
///
/// "Тема приложения выводится из activeProfile.type" (§5.2, §13.1). The light scheme is primary;
/// dark is a supported mode. UI reads these semantic tokens via `@Environment(\.theme)`; it should
/// not reach for raw ``BrandColors`` directly.
struct Theme: Equatable, Sendable {
    var scheme: ColorScheme
    var profileType: ProfileType?

    // Surfaces
    var background: Color
    var surface: Color
    var elevated: Color
    var border: Color

    // Text
    var textPrimary: Color
    var textSecondary: Color

    // Accent (per profile context)
    var accent: Color
    var onAccent: Color

    // Crypto / AI — cold gradient stops (separates from fiat, §13.1)
    var accentCrypto: [Color]

    // Status
    var success: Color
    var danger: Color
    var warning: Color

    /// The crypto/AI cold gradient as a ready-to-use `LinearGradient`.
    var cryptoGradient: LinearGradient {
        LinearGradient(colors: accentCrypto, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var isDark: Bool { scheme == .dark }

    /// Resolve a theme from a profile type and color scheme. `profileType == nil` → personal.
    static func resolve(for profileType: ProfileType?, scheme: ColorScheme = .light) -> Theme {
        let dark = scheme == .dark
        // Business gets its OWN graphite base, not just a graphite accent (§8/§13.1) — so the
        // business mode is visibly a different context, not only differently-tinted buttons.
        let isBusiness = profileType == .business

        let background: Color
        let surface: Color
        let elevated: Color
        let border: Color
        if isBusiness {
            background = dark ? BrandColors.bizBgDark       : BrandColors.bizBgLight
            surface    = dark ? BrandColors.bizSurfaceDark  : BrandColors.bizSurfaceLight
            elevated   = dark ? BrandColors.bizElevatedDark : BrandColors.bizElevatedLight
            border     = dark ? BrandColors.bizBorderDark   : BrandColors.bizBorderLight
        } else {
            background = dark ? BrandColors.nearBlack    : BrandColors.paper
            surface    = dark ? BrandColors.graphite900  : BrandColors.surfaceLight
            elevated   = dark ? BrandColors.graphite800  : BrandColors.elevatedLight
            border     = dark ? BrandColors.graphite700  : BrandColors.borderLight
        }
        let textPrimary   = dark ? BrandColors.inkOnDark    : BrandColors.inkOnLight
        let textSecondary = dark ? BrandColors.mutedOnDark  : BrandColors.mutedOnLight

        let accent: Color
        let onAccent: Color
        switch profileType {
        case .business:
            // Graphite/steel context (§5.2, §8): a light platinum accent on dark → dark text on it.
            accent = dark ? BrandColors.businessPlatinum : BrandColors.businessGraphite
            onAccent = dark ? BrandColors.black : BrandColors.white
        case .child:
            accent = dark ? BrandColors.childViolet : BrandColors.childVioletLight
            onAccent = BrandColors.white
        case .joint:
            // Family/joint gets its own context color (§5.2) — no silent fallback to personal.
            accent = dark ? BrandColors.jointTeal : BrandColors.jointTealLight
            onAccent = dark ? BrandColors.black : BrandColors.white
        case .personal, .none:
            accent = dark ? BrandColors.heritageRed : BrandColors.heritageRedLight
            onAccent = BrandColors.white
        }

        let success = dark ? BrandColors.successDark : BrandColors.successLight
        let danger  = dark ? BrandColors.dangerDark  : BrandColors.dangerLight
        let warning = dark ? BrandColors.warningDark : BrandColors.warningLight

        return Theme(
            scheme: scheme,
            profileType: profileType,
            background: background,
            surface: surface,
            elevated: elevated,
            border: border,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            accent: accent,
            onAccent: onAccent,
            accentCrypto: [BrandColors.cryptoBlue, BrandColors.cryptoCyan],
            success: success,
            danger: danger,
            warning: warning
        )
    }

    /// Primary (light · personal) theme — the default environment value.
    static let `default` = Theme.resolve(for: nil, scheme: .light)
}
