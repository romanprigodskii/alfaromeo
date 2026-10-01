import SwiftUI

/// Resolved, semantic color theme for the current profile context + color scheme (docs/DESIGN.md §2).
///
/// The app theme follows `activeProfile.type`. Light is primary; dark is supported. UI reads these
/// semantic tokens via `@Environment(\.theme)`; it does not reach for raw ``BrandColors``.
struct Theme: Equatable, Sendable {
    var scheme: ColorScheme
    var profileType: ProfileType?

    // Surfaces
    /// Screen background.
    var background: Color
    /// Grouped lists, sheets, standalone cards.
    var surface: Color
    /// Inputs and nested controls drawn on a surface.
    var elevated: Color
    /// Neutral control background: secondary button, quick-action circle, glyph circle, skeletons.
    var fill: Color
    /// Hairlines (0.5pt).
    var border: Color

    // Text
    var textPrimary: Color
    var textSecondary: Color
    /// Placeholders, disabled text, chevrons.
    var textTertiary: Color

    // Accent (per profile context). The one accent: primary CTA, selection, links.
    var accent: Color
    var onAccent: Color

    /// Legacy crypto gradient stops. Retired by DESIGN.md §2; kept so existing call sites compile until
    /// the crypto module is redesigned. Do not use in new code.
    var accentCrypto: [Color]

    // Status: state and signed amounts only, never decoration.
    var success: Color
    var danger: Color
    var warning: Color

    /// Legacy crypto gradient. Do not use in new code (DESIGN.md §2: no decorative gradients).
    var cryptoGradient: LinearGradient {
        LinearGradient(colors: accentCrypto, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var isDark: Bool { scheme == .dark }

    /// Status hue as TEXT on a pale tint of itself (badges, pills). In light mode the saturated hues
    /// fail AA there, so the darker ink variants are used.
    func statusInk(_ role: StatusRole) -> Color {
        switch role {
        case .success: return isDark ? success : BrandColors.successInkLight
        case .danger:  return isDark ? danger  : BrandColors.dangerInkLight
        case .warning: return isDark ? warning : BrandColors.warningInkLight
        }
    }

    /// The semantic status role a color plays in this theme, if any. Lets components honour a tint
    /// only when it carries meaning (success / danger / warning) and stay neutral otherwise.
    func statusRole(of color: Color?) -> StatusRole? {
        guard let color else { return nil }
        if color == success || color == BrandColors.successInkLight { return .success }
        if color == danger  || color == BrandColors.dangerInkLight  { return .danger }
        if color == warning || color == BrandColors.warningInkLight { return .warning }
        return nil
    }

    enum StatusRole: Sendable { case success, danger, warning }

    /// Resolve a theme from a profile type and color scheme. `profileType == nil` means personal.
    static func resolve(for profileType: ProfileType?, scheme: ColorScheme = .light) -> Theme {
        let dark = scheme == .dark
        // Business gets its own cool graphite base, so the business mode reads as a different context.
        let isBusiness = profileType == .business

        let background: Color
        let surface: Color
        let elevated: Color
        let fill: Color
        let border: Color
        if isBusiness {
            background = dark ? BrandColors.bizBgDark       : BrandColors.bizBgLight
            surface    = dark ? BrandColors.bizSurfaceDark  : BrandColors.bizSurfaceLight
            elevated   = dark ? BrandColors.bizElevatedDark : BrandColors.bizElevatedLight
            fill       = dark ? BrandColors.bizFillDark     : BrandColors.bizFillLight
            border     = dark ? BrandColors.bizBorderDark   : BrandColors.bizBorderLight
        } else {
            background = dark ? BrandColors.nearBlack    : BrandColors.paper
            surface    = dark ? BrandColors.graphite900  : BrandColors.surfaceLight
            elevated   = dark ? BrandColors.graphite800  : BrandColors.elevatedLight
            fill       = dark ? BrandColors.fillDark     : BrandColors.fillLight
            border     = dark ? BrandColors.graphite700  : BrandColors.borderLight
        }
        let textPrimary   = dark ? BrandColors.inkOnDark   : BrandColors.inkOnLight
        let textSecondary = dark ? BrandColors.mutedOnDark : BrandColors.mutedOnLight
        let textTertiary  = dark ? BrandColors.faintOnDark : BrandColors.faintOnLight

        let accent: Color
        let onAccent: Color
        switch profileType {
        case .business:
            // Graphite/steel context: a light platinum accent on dark carries dark text.
            accent = dark ? BrandColors.businessPlatinum : BrandColors.businessGraphite
            onAccent = dark ? BrandColors.black : BrandColors.white
        case .child:
            accent = dark ? BrandColors.childViolet : BrandColors.childVioletLight
            onAccent = BrandColors.white
        case .joint:
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
            fill: fill,
            border: border,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            accent: accent,
            onAccent: onAccent,
            accentCrypto: [BrandColors.cryptoBlue, BrandColors.cryptoCyan],
            success: success,
            danger: danger,
            warning: warning
        )
    }

    /// Primary (light, personal) theme: the default environment value.
    static let `default` = Theme.resolve(for: nil, scheme: .light)
}
