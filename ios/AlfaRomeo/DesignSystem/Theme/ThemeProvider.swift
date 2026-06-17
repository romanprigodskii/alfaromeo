import SwiftUI

// MARK: - Environment value

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .default
}

extension EnvironmentValues {
    /// The active semantic theme. Injected by ``ThemeProvider`` (DI via the SwiftUI environment).
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Provider

/// Resolves a ``Theme`` from a profile type + color scheme, injects it into the environment, and
/// applies the matching system color scheme + accent tint. Light is primary; dark is a supported
/// mode (§13.1).
///
/// `scheme` is optional: `nil` means **follow the device** (the «Система» theme preference, §9.8) — the
/// palette is then resolved from the ambient `\.colorScheme` and no `preferredColorScheme` is pinned.
/// A non-nil value pins light or dark explicitly. The app root passes the user's persisted preference.
struct ThemeProvider<Content: View>: View {
    var profileType: ProfileType?
    var scheme: ColorScheme?
    @Environment(\.colorScheme) private var systemScheme
    @ViewBuilder var content: () -> Content

    init(profileType: ProfileType? = nil,
         scheme: ColorScheme? = .light,
         @ViewBuilder content: @escaping () -> Content) {
        self.profileType = profileType
        self.scheme = scheme
        self.content = content
    }

    var body: some View {
        // When following the system (`scheme == nil`), resolve the palette from the device appearance.
        let theme = Theme.resolve(for: profileType, scheme: scheme ?? systemScheme)
        content()
            .environment(\.theme, theme)
            .tint(theme.accent)
            .preferredColorScheme(scheme)   // nil → no override → follow the device
    }
}

extension View {
    /// Wrap a subtree in a ``ThemeProvider``. `scheme: nil` follows the device appearance.
    func themeProvider(profileType: ProfileType? = nil, scheme: ColorScheme? = .light) -> some View {
        ThemeProvider(profileType: profileType, scheme: scheme) { self }
    }
}
