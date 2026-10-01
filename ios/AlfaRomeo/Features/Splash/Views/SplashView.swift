import SwiftUI

/// Splash: shows the wordmark while checking for an existing session (§9.0). In the mock there is
/// no persisted session, so it routes to the pre-auth flow; a real build would validate a stored
/// token and jump straight to `.authenticated`.
struct SplashView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                Spacer()
                BrandMark(subtitle: nil)
                Spacer()
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.textSecondary)
                    .padding(.bottom, Spacing.xxl)
            }
        }
        .task {
            // Simulate a session check, then enter the pre-auth flow.
            try? await Task.sleep(for: .milliseconds(700))
            if session.authState == .splash {
                session.authState = .unauthenticated
            }
        }
    }
}

#Preview {
    SplashView()
        .environment(AppSession())
        .environment(\.theme, .default)
}
