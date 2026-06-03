import SwiftUI

/// The pre-auth flow (§9.0). New users start at onboarding; returning users (after a logout) start
/// at login. Pushes onto a single NavigationStack driven by ``AuthCoordinator``.
struct PreAuthFlowView: View {
    @Environment(AppSession.self) private var session
    @State private var coordinator = AuthCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            Group {
                if session.isReturningUser {
                    LoginView()
                } else {
                    OnboardingView()
                }
            }
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .login:     LoginView()
                case .register:  RegistrationView()
                case .newDevice: NewDeviceView()
                }
            }
        }
        .environment(coordinator)
    }
}
