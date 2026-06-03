import Foundation

/// Errors surfaced by ``APIClient`` implementations.
enum APIError: Error, Equatable {
    case notImplemented
    case invalidResponse
    case http(status: Int)
    case decoding(String)
    case transport(String)
}
