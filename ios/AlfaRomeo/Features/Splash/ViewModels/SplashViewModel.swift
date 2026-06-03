import Observation

/// Demonstrates the MVVM + `@Observable` convention.
///
/// In Phase 0 it is effectively a no-op. Phase 0.2 will use the injected ``APIClient`` to check
/// the session/health and drive `AppSession.authState` (splash → auth → home).
@MainActor
@Observable
final class SplashViewModel {
    private(set) var isReady = false

    func bootstrap(using client: any APIClient) async {
        // Phase 0: no feature work. Wiring lands in Phase 0.2.
        isReady = true
    }
}
