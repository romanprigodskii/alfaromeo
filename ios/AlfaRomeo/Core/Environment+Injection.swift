import SwiftUI

/// Dependency injection through the SwiftUI environment (DI pin).
///
/// - ``AppSession`` is an `@Observable` object → injected with `.environment(_:)` and read with
///   `@Environment(AppSession.self)`.
/// - ``APIClient`` is a protocol → injected through this custom `EnvironmentKey`, defaulting to
///   ``MockAPIClient`` so previews and the scaffold work without a live backend.
private struct APIClientKey: EnvironmentKey {
    static let defaultValue: any APIClient = MockAPIClient()
}

extension EnvironmentValues {
    var apiClient: any APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}
