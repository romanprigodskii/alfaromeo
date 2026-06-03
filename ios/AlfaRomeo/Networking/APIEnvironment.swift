import Foundation

/// Backend environment selector — the base URL source for ``LiveAPIClient`` and ``PriceSocket``.
///
/// Named `APIEnvironment` to avoid colliding with SwiftUI's `Environment` property wrapper.
enum APIEnvironment {
    case dev
    case staging
    case production

    /// The environment the current build targets.
    static let current: APIEnvironment = .production

    /// Dev backend host. The port defaults to the documented backend `PORT=4000` (the backend ships
    /// on 4000 to dodge the common :3000 collision, §14) and can be overridden at runtime via the
    /// `AR_BACKEND_PORT` UserDefaults key — so the debug screen can retarget without a rebuild.
    static let devHost = "localhost"
    static var devPort: Int {
        if let raw = UserDefaults.standard.string(forKey: "AR_BACKEND_PORT"), let p = Int(raw) { return p }
        return 4000
    }

    /// REST base URL.
    var baseURL: URL {
        switch self {
        case .dev:        return URL(string: "http://\(APIEnvironment.devHost):\(APIEnvironment.devPort)")!
        case .staging:    return URL(string: "https://staging.api.alfa-romeo.bank")!
        case .production: return URL(string: "https://api.alfa-romeo.uk")!
        }
    }

    /// WebSocket base URL — prices / balances / statuses (§11.9).
    var webSocketURL: URL {
        switch self {
        case .dev:        return URL(string: "ws://\(APIEnvironment.devHost):\(APIEnvironment.devPort)/ws")!
        case .staging:    return URL(string: "wss://staging.api.alfa-romeo.bank/ws")!
        case .production: return URL(string: "wss://api.alfa-romeo.uk/ws")!
        }
    }

    /// The live price stream endpoint — backend fans out one upstream connection here (§11.4).
    /// `ws://<host>/ws/prices`.
    var pricesWebSocketURL: URL {
        webSocketURL.appendingPathComponent("prices")
    }
}
