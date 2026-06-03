import SwiftUI
import Observation

/// Pushed destinations in the pre-auth flow (§9.0).
enum AuthRoute: Hashable {
    case login
    case register
    case newDevice
}

/// Navigation coordinator for the pre-auth `NavigationStack`.
@MainActor
@Observable
final class AuthCoordinator {
    var path = NavigationPath()

    func push(_ route: AuthRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func reset() { path = NavigationPath() }
}
