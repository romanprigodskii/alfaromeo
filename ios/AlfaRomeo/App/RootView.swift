import SwiftUI

/// Root of the view tree. Applies the theme from the active profile (via ``ThemeProvider``) and
/// routes on auth state: splash / pre-auth ↔ the authenticated shell (§9).
struct RootView: View {
    @Environment(AppSession.self) private var session
    @State private var settings = SettingsStore.shared

    var body: some View {
        // The user's persisted theme choice (§9.8) drives the whole app's scheme — `nil` follows device.
        ThemeProvider(profileType: session.activeProfile?.type,
                      scheme: settings.themePreference.preferredColorScheme) {
            switch session.authState {
            case .splash:
                SplashView()
            case .unauthenticated:
                PreAuthFlowView()
            case .authenticated:
                AppShell()
                    .priceAlertHost()
            }
        }
    }
}

#Preview("Personal shell") {
    RootView()
        .environment(AppSession.mockAuthenticated())
}

#Preview("Business shell") {
    RootView()
        .environment({
            let session = AppSession.mockAuthenticated()
            session.debugSetActiveProfileType(.business)
            return session
        }())
}
