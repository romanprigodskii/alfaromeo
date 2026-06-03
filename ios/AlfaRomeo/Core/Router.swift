import SwiftUI
import Observation

/// Per-tab navigation coordinator over `NavigationStack`.
///
/// Pin: "собственный Router/coordinator на каждую таб-секцию". Each tab section owns its own
/// `Router`; routes are `Hashable` values pushed onto `path`, and destinations are resolved with
/// `.navigationDestination(...)` in the tab root (wired per feature in later phases).
@MainActor
@Observable
final class Router {
    var path = NavigationPath()

    func push<Route: Hashable>(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
